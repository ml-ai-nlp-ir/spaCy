# cython: profile=True
"""
Fill an array, context, with every _atomic_ value our features reference.
We then write the _actual features_ as tuples of the atoms. The machinery
that translates from the tuples to feature-extractors (which pick the values
out of "context") is in features/extractor.pyx

The atomic feature names are listed in a big enum, so that the feature tuples
can refer to them.
"""
from itertools import combinations

from ..tokens cimport TokenC
from ._state cimport State
from ._state cimport get_s2, get_s1, get_s0, get_n0, get_n1, get_n2
from ._state cimport get_left, get_right


cdef inline void fill_token(atom_t* context, const TokenC* token) nogil:
    if token is NULL:
        context[0] = 0
        context[1] = 0
        context[2] = 0
        context[3] = 0
        context[4] = 0
        context[5] = 0
    else:
        context[0] = token.lex.sic
        context[1] = token.pos
        context[2] = token.lex.cluster
        # We've read in the string little-endian, so now we can take & (2**n)-1
        # to get the first n bits of the cluster.
        # e.g. s = "1110010101"
        # s = ''.join(reversed(s))
        # first_4_bits = int(s, 2)
        # print first_4_bits
        # 5
        # print "{0:b}".format(prefix).ljust(4, '0')
        # 1110
        # What we're doing here is picking a number where all bits are 1, e.g.
        # 15 is 1111, 63 is 111111 and doing bitwise AND, so getting all bits in
        # the source that are set to 1.
        context[3] = token.lex.cluster & 63
        context[4] = token.lex.cluster & 15
        context[5] = token.dep_tag


cdef int fill_context(atom_t* context, State* state) except -1:
    # This fills in the basic properties of each of our "slot" tokens, e.g.
    # word on top of the stack, word at the front of the buffer, etc.
    fill_token(&context[S2w], get_s2(state))
    fill_token(&context[S1w], get_s1(state))
    fill_token(&context[S1rw], get_right(state, get_s1(state), 1))
    fill_token(&context[S0lw], get_left(state, get_s0(state), 1))
    fill_token(&context[S0l2w], get_left(state, get_s0(state), 2))
    fill_token(&context[S0w], get_s0(state))
    fill_token(&context[S0r2w], get_right(state, get_s0(state), 2))
    fill_token(&context[S0rw], get_right(state, get_s0(state), 1))
    fill_token(&context[N0lw], get_left(state, get_n0(state), 1))
    fill_token(&context[N0l2w], get_left(state, get_n0(state), 2))
    fill_token(&context[N0w], get_n0(state))
    fill_token(&context[N1w], get_n1(state))
    fill_token(&context[N2w], get_n2(state))

    if state.stack_len >= 1:
        context[dist] = state.stack[0] - state.i
    else:
        context[dist] = 0
    context[N0lv] = 0 
    context[S0lv] = 0
    context[S0rv] = 0
    context[S1lv] = 0
    context[S1rv] = 0


arc_eager = (
    (S0w, S0p),
    (S0w,),
    (S0p,),
    (N0w, N0p),
    (N0w,),
    (N0p,),
    (N1w, N1p),
    (N1w,),
    (N1p,),
    (N2w, N2p),
    (N2w,),
    (N2p,),

    (S0w, S0p, N0w, N0p),
    (S0w, S0p, N0w),
    (S0w, N0w, N0p),
    (S0w, S0p, N0p),
    (S0p, N0w, N0p),
    (S0w, N0w),
    (S0p, N0p),
    (N0p, N1p),
    (N0p, N1p, N2p),
    (S0p, N0p, N1p),
    (S1p, S0p, N0p),
    (S0p, S0lp, N0p),
    (S0p, S0rp, N0p),
    (S0p, N0p, N0lp),
    (dist, S0w),
    (dist, S0p),
    (dist, N0w),
    (dist, N0p),
    (dist, S0w, N0w),
    (dist, S0p, N0p),
    (S0w, S0rv),
    (S0p, S0rv),
    (S0w, S0lv),
    (S0p, S0lv),
    (N0w, N0lv),
    (N0p, N0lv),
    (S1w,),
    (S1p,),
    (S0lw,),
    (S0lp,),
    (S0rw,),
    (S0rp,),
    (N0lw,),
    (N0lp,),
    (S2w,),
    (S2p,),
    (S0l2w,),
    (S0l2p,),
    (S0r2w,),
    (S0r2p,),
    (N0l2w,),
    (N0l2p,),
    (S0p, S0lp, S0l2p),
    (S0p, S0rp, S0r2p),
    (S0p, S1p, S2p),
    (N0p, N0lp, N0l2p),
    (S0L,),
    (S0lL,),
    (S0rL,),
    (N0lL,),
    (S1L,),
    (S0l2L,),
    (S0r2L,),
    (N0l2L,),
    (S0w, S0rL, S0r2L),
    (S0p, S0rL, S0r2L),
    (S0w, S0lL, S0l2L),
    (S0p, S0lL, S0l2L),
    (N0w, N0lL, N0l2L),
    (N0p, N0lL, N0l2L),
)


label_sets = (
   (S0w, S0lL, S0l2L),
   (S0p, S0rL, S0r2L),
   (S0p, S0lL, S0l2L),
   (S0p, S0rL, S0r2L),
   (N0w, N0lL, N0l2L),
   (N0p, N0lL, N0l2L),
)

extra_labels = (
    (S0p, S0lL, S0lp),
    (S0p, S0lL, S0l2L),
    (S0p, S0rL, S0rp),
    (S0p, S0rL, S0r2L),
    (S0p, S0lL, S0rL),
    (S1p, S0L, S0rL),
    (S1p, S0L, S0lL),
)


# Koo et al (2008) dependency features, using Brown clusters.
clusters = (
    # Koo et al have (head, child) --- we have S0, N0 for both.
    (S0c4, N0c4),
    (S0c6, N0c6),
    (S0c, N0c),
    (S0p, N0c4),
    (S0p, N0c6),
    (S0p, N0c),
    (S0c4, N0p),
    (S0c6, N0p),
    (S0c, N0p),
    # Siblings --- right arc
    (S0c4, S0rc4, N0c4),
    (S0c6, S0rc6, N0c6),
    (S0p, S0rc4, N0c4),
    (S0c4, S0rp, N0c4),
    (S0c4, S0rc4, N0p),
    # Siblings --- left arc
    (S0c4, N0lc4, N0c4),
    (S0c6, N0c6, N0c6),
    (S0c4, N0lc4, N0p),
    (S0c4, N0lp, N0c4),
    (S0p, N0lc4, N0c4),
    # Grand-child, right-arc
    (S1c4, S0c4, N0c4),
    (S1c6, S0c6, N0c6),
    (S1p, S0c4, N0c4),
    (S1c4, S0p, N0c4),
    (S1c4, S0c4, N0p),
    # Grand-child, left-arc
    (S0lc4, S0c4, N0c4),
    (S0lc6, S0c6, N0c6),
    (S0lp, S0c4, N0c4),
    (S0lc4, S0p, N0c4),
    (S0lc4, S0c4, N0p)
)


def pos_bigrams():
    kernels = [S2w, S1w, S0w, S0lw, S0rw, N0w, N0lw, N1w]
    bitags = []
    for t1, t2 in combinations(kernels, 2):
        feat = (t1 + 1, t2 + 1)
        bitags.append(feat)
    print "Adding %d bitags" % len(bitags)
    return tuple(bitags)