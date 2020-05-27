#!/usr/bin/env python

def ben_encrypt(msg, pad):
    """Encrypts message `msg' using Ben's One-time-pad with feedback
    algorithm"""
    assert len(msg) == len(pad)
    prev_c = 0
    result = []
    for i in xrange(len(msg)):
        c = msg[i] ^ ((pad[i] + prev_c) % 256)
        result.append(c)
        prev_c = c
    return result

def ben_decrypt(ctext, pad):
    assert len(ctext) == len(pad)
    prev_c = 0
    result = []
    for i in xrange(len(ctext)):
        b = ctext[i] ^ ((pad[i] + prev_c) % 256)
        result.append(b)
        prev_c = ctext[i]
    return result

def text_to_bytes(t):
    return [ord(c) for c in t]

def test_ben_encrypt_decrypt():
    m = text_to_bytes("message!")
    p = text_to_bytes("password")
    c = ben_encrypt(m, p)
    d = ben_decrypt(c, p)
    assert m == d

if __name__ == '__main__':
    test_ben_encrypt_decrypt()
