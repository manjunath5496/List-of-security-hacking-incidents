#!/usr/bin/env python
from __future__ import division
import random

# The GF16 implementation below is quite slow, but provided here for
# educational purposes. You might be better off by using hard-coded
# multiplication/addition/inversion tables, if you need more than
# moderate computational resources.

class GF16(object):
    """Implementation of GF(2^4) as degree 4 polynomials over GF(2) modulo
    x^4 + x + 1.

    """
    def __init__(self, val):
        if not (isinstance(val, int) or isinstance(val, long)) or val < 0 or val > 15:
            raise ValueError("GF16 elements must be constructed from integers from 0 to 15.")
        self.val = val

    def __repr__(self):
        return "GF16(%d)" % self.val

    def __add__(self, other):
        if not isinstance(other, GF16):
            raise ValueError("Addition is only defined between a GF16 element and GF16 element")
        return GF16(self.val ^ other.val)

    def __sub__(self, other):
        if not isinstance(other, GF16):
            raise ValueError("Subtraction is only defined between a GF16 element and GF16 element")
        # +1 equals -1 (mod 2), so both operations are XOR
        return GF16(self.val ^ other.val)

    def __neg__(self):
        # +1 equals -1 (mod 2), so negation is the same element
        return GF16(self.val)

    def __mul__(self, other):
        # See http://en.wikipedia.org/wiki/Finite_field_arithmetic
        if not isinstance(other, GF16):
            raise ValueError("Multiplication is only defined between a GF16 element and GF16 element")

        a, b = self.val, other.val
        r = 0
        for c in xrange(4):
            if b & 1:
                r = r^a
            a <<= 1
            if a & 16 == 16:
                a ^= (16 + 2 + 1) # subtract x^4 + x + 1
            b >>= 1
        return GF16(r)

    def __div__(self, other):
        if not isinstance(other, GF16):
            raise ValueError("Division is only defined between a GF16 element and GF16 element")
        return self * other.inverse()

    __truediv__ = __div__

    def __eq__(self, other):
        if isinstance(other, GF16):
            return self.val == other.val
        else:
            return False

    def __ne__(self, other):
        if isinstance(other, GF16):
            return self.val != other.val
        else:
            return True

    def inverse(self):
        if self.val == 0:
            raise ValueError("Zero is not invertible.")
        # We know that x^15 = x^14 * x = 1, so x^14 = x^{-1}
        s2 = self * self
        s4 = s2 * s2
        s7 = self * s2 * s4
        s14 = s7 * s7
        return s14

def test_GF16():
    # associativity
    for a in xrange(16):
        for b in xrange(16):
            for c in xrange(16):
                assert GF16(a) * (GF16(b) * GF16(c)) == (GF16(a) * GF16(b)) * GF16(c)
                assert GF16(a) + (GF16(b) + GF16(c)) == (GF16(a) + GF16(b)) + GF16(c)

    # commutativity
    for a in xrange(16):
        for b in xrange(16):
            assert GF16(a) * GF16(b) == GF16(b) * GF16(a)
            assert GF16(a) + GF16(b) == GF16(b) + GF16(a)

    # distributivity
    for a in xrange(16):
        for b in xrange(16):
            for c in xrange(16):
                assert GF16(a) * (GF16(b) + GF16(c)) == GF16(a) * GF16(b) + GF16(a) * GF16(c)

    # inverses
    for a in xrange(16):
        assert GF16(a) + (-GF16(a)) == GF16(0)
    for a in xrange(1, 16):
        assert GF16(a) * (GF16(a).inverse()) == GF16(1)

def matrix_by_vector(A, x):
    zero = type(x[0])(0)
    result = []
    for row in A:
        assert len(row) == len(x)
        c = sum((rowi * xi for rowi, xi in zip(row, x)), zero)
        result.append(c)
    return result

def matrix_by_matrix(A, B):
    zero = type(A[0][0])(0)
    C = []
    for i in xrange(len(A)):
        Ci = []
        for j in xrange(len(A[i])):
            Cij = sum((A[i][k] * B[k][j] for k in xrange(len(A[i]))), zero)
            Ci.append(Cij)
        C.append(Ci)
    return C

def matrix_inverse(A):
    # O(n^3) inversion using Gauss-Jordan algorithm
    zero = type(A[0][0])(0)
    one = type(A[0][0])(1)
    n = len(A)
    M = [A[i] + [zero] * i + [one] + [zero] * (n-1-i) for i in xrange(n)] # augment with identity matrix

    # first make the matrix in upper-triangular form
    for i in xrange(n):
        pivot = None
        for j in xrange(i, n):
            if M[j][i] != zero:
                pivot = j
                break

        if pivot is None:
            raise ValueError, "Matrix is not invertible?"

        # swap rows i and pivot
        if pivot != i:
            M[pivot], M[i] = M[i], M[pivot]

        # divide out the row itself by the diagonal element
        multiple = M[i][i]
        for k in xrange(2*n):
            M[i][k] /= multiple

        # subtract this row appropriate number of times for every row below it
        for j in xrange(i+1, n):
            multiple = M[j][i]
            for k in xrange(2*n):
                M[j][k] -= M[i][k] * multiple

    # then work our way back up
    for i in xrange(n-1, -1, -1):
        for j in xrange(i-1, -1, -1):
            multiple = M[j][i]
            for k in xrange(2*n):
                M[j][k] -= M[i][k] * multiple

    # return the augmented part
    return [M[i][n:] for i in xrange(n)]

def test_matrix_inverse(n):
    r = range(n)
    random.shuffle(r)
    P = [[GF16(0)] * n for i in xrange(n)]
    L = [[GF16(0)] * n for i in xrange(n)]
    U = [[GF16(0)] * n for i in xrange(n)]
    for i in xrange(n):
        P[i][r[i]] = GF16(1)
        L[i][i] = GF16(random.randint(1, 15))
        U[i][i] = GF16(random.randint(1, 15))
        for j in xrange(i):
            L[i][j] = GF16(random.randint(0, 15))
        for j in xrange(i+1, n):
            U[i][j] = GF16(random.randint(0, 15))

    M = matrix_by_matrix(matrix_by_matrix(L, U), P)
    Minv = matrix_inverse(M)
    MMinv = matrix_by_matrix(M, Minv)
    for i in xrange(n):
        for j in xrange(n):
            assert MMinv[i][j] == (GF16(1) if i == j else GF16(0))

def vector_add(u, v):
    assert len(u) == len(v)
    return [ui + vi for ui, vi in zip(u, v)]

def vector_sub(u, v):
    assert len(u) == len(v)
    return [ui - vi for ui, vi in zip(u, v)]

def random_GF16_vector(n):
    return [GF16(random.randint(0, 15)) for i in xrange(n)]

def random_GF16_matrix(n):
    return [random_GF16_vector(n) for i in xrange(n)]

def random_invertible_GF16_matrix(n):
    while True:
        M = random_GF16_matrix(n)
        try:
            Minv = matrix_inverse(M)
        except ValueError, e:
            continue
        return M

def int64_to_GF16_vec(x):
    v = [None] * 16
    for i in xrange(16):
        v[15-i] = GF16(x & 15)
        x >>= 4
    assert x == 0
    return v

def GF16_vec_to_int64(v):
    assert len(v) == 16
    x = 0
    for el in v:
        x = (x << 4) | el.val
    return x

class Kalns(object):
    def __init__(self, A=None, b=None, S=None):
        self.A = A if A else random_invertible_GF16_matrix(16)
        self.b = b if b else random_GF16_vector(16)
        if S:
            self.S = S
        else:
            self.S = range(16)
            random.shuffle(self.S)

        # pre-compute inverses for dec
        self.Ainv = matrix_inverse(self.A)
        self.Sinv = [None] * 16
        for i in xrange(16):
            self.Sinv[self.S[i]] = i

        # counters
        self.enc_count = 0
        self.dec_count = 0

    def enc(self, x):
        self.enc_count += 1
        x_vec = int64_to_GF16_vec(x)
        u = matrix_by_vector(self.A, x_vec)
        v = vector_add(u, self.b)
        t = [GF16(self.S[el.val]) for el in v]
        return GF16_vec_to_int64(t)

    def dec(self, t):
        self.dec_count += 1
        v = [GF16(self.Sinv[el.val]) for el in int64_to_GF16_vec(t)]
        u = vector_sub(v, self.b)
        x_vec = matrix_by_vector(self.Ainv, u)
        return GF16_vec_to_int64(x_vec)

import urllib
def remote_query(s):
    return urllib.urlopen('http://6857.scripts.mit.edu/kalns/' + s).read()

class RemoteKalns(object):
    def __init__(self, token):
        self.token = token

    def enc(self, x):
        resp = remote_query('enc?token=%s&msg=%d' % (self.token, x))
        if resp.isdigit():
            return int(resp)
        else:
            return resp

    def dec(self, t):
        resp = remote_query('dec?token=%s&msg=%d' % (self.token, t))
        if resp.isdigit():
            return int(resp)
        else:
            return resp

    def answer(self, A, b, S):
        Avec = []
        for row in A:
            Avec += [x.val for x in row]

        Astr = ','.join(str(x) for x in Avec)
        bstr = ','.join(str(x.val) for x in b)
        Sstr = ','.join(str(x) for x in S)

        resp = remote_query('answer?token=%s&Avec=%s&bvec=%s&Svec=%s' % (self.token, Astr, bstr, Sstr))
        return resp

def test_Kalns():
    box = Kalns()
    x = random.randint(0, (1<<64)-1)
    e = box.enc(x)
    d = box.dec(e)
    assert d == x

if __name__ == '__main__':
    test_GF16()
    test_matrix_inverse(16)
    test_Kalns()
