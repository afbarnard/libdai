"""Tests the Python interface to libDAI.

These tests focus on the correct operation of the API and not on libDAI
itself though many of the tests would be same in both cases.  In
particular, the tests for API functionality added in the Swig interface
are important.

Currently requires Python 2.7.
"""


import math
import unittest

import dai


class VarTest(unittest.TestCase):

    def setUp(self):
        self.vars = [
            dai.Var(0, 5),
            dai.Var(1, 6),
            ]

    def tearDown(self):
        """Implement this in hopes of catching destructor problems."""
        for index in xrange(len(self.vars)):
            self.vars[index] = None
        self.vars = None

    def test_label(self):
        self.assertEqual(0, self.vars[0].label())
        self.assertEqual(1, self.vars[1].label())

    def test_states(self):
        self.assertEqual(5, self.vars[0].states())
        self.assertEqual(6, self.vars[1].states())

    def test___lt__(self):
        """operator<"""
        self.assertLess(self.vars[0], self.vars[1])

    def test___gt__(self):
        """operator>"""
        self.assertGreater(self.vars[1], self.vars[0])

    def test___le__(self):
        """operator<="""
        self.assertLessEqual(self.vars[0], self.vars[1])
        self.assertLessEqual(self.vars[0], dai.Var(0, 5))

    def test___ge__(self):
        """operator>="""
        self.assertGreaterEqual(self.vars[1], self.vars[0])
        self.assertGreaterEqual(self.vars[1], dai.Var(1, 6))

    def test___eq__(self):
        """operator=="""
        self.assertEqual(self.vars[0], dai.Var(0, 5))

    def test___ne__(self):
        """operator!="""
        self.assertNotEqual(self.vars[0], self.vars[1])

    def test___repr__(self):
        self.assertEqual('Var(0, 5)', repr(self.vars[0]))


class SmallSetSizetTest(unittest.TestCase):

    """It should be sufficient for this test of SmallSet<size_t> to
    stand in for tests of all other template instantiations of
    SmallSet<T> including VarSet.
    """

    def setUp(self):
        self.sets = [
            dai.SmallSetSizet(),
            dai.SmallSetSizet(4, 23),
            dai.SmallSetSizet(range(10)),
            ]

    def tearDown(self):
        '''Implement this in hopes of catching destructor problems.'''
        for index in xrange(len(self.sets)):
            self.sets[index] = None
        self.sets = None

    def test_insert(self):
        self.sets[0].insert(67)
        self.assertEqual(1, self.sets[0].size())
        self.assertTrue(self.sets[0].contains(67))

    def test_erase(self):
        self.sets[1].erase(4)
        self.assertEqual(1, self.sets[1].size())
        self.assertFalse(self.sets[1].contains(4))

    def test_intersects(self):
        self.assertTrue(self.sets[1].intersects(self.sets[1]))
        self.assertTrue(self.sets[1].intersects(self.sets[2]))
        self.assertFalse(self.sets[1].intersects(self.sets[0]))

    def test_contains(self):
        self.assertTrue(self.sets[1].contains(23))
        self.assertFalse(self.sets[1].contains(24))
        self.assertTrue(self.sets[2].contains(7))
        self.assertFalse(self.sets[2].contains(17))

    def test___contains__(self):
        self.assertTrue(23 in self.sets[1])
        self.assertFalse(24 in self.sets[1])
        self.assertTrue(self.sets[2].contains(7))
        self.assertFalse(self.sets[2].contains(17))

    def test_size(self):
        self.assertEqual(0, self.sets[0].size())
        self.assertEqual(2, self.sets[1].size())
        self.assertEqual(10, self.sets[2].size())

    def test___len__(self):
        self.assertEqual(0, len(self.sets[0]))
        self.assertEqual(2, len(self.sets[1]))
        self.assertEqual(10, len(self.sets[2]))

    def test_empty(self):
        self.assertTrue(self.sets[0].empty())
        self.assertFalse(self.sets[1].empty())
        self.assertFalse(self.sets[2].empty())

    def test___nonzero__(self):
        self.assertFalse(self.sets[0])
        self.assertTrue(self.sets[1])
        self.assertTrue(self.sets[2])

    def test_elements(self):
        self.assertEqual((), self.sets[0].elements())
        self.assertEqual((4, 23), self.sets[1].elements())
        self.assertEqual(tuple(xrange(10)), self.sets[2].elements())

    def test_front(self):
        self.assertEqual(4, self.sets[1].front())

    def test_back(self):
        self.assertEqual(9, self.sets[2].back())

    def test___eq__(self):
        """operator=="""
        self.assertEqual(self.sets[1], dai.SmallSetSizet(4, 23))

    def test___ne__(self):
        """operator!="""
        self.assertNotEqual(self.sets[0], self.sets[1])

    def test___lt__(self):
        """operator<"""
        # Lexicographic ordering (length not considered)
        self.assertLess(self.sets[0], self.sets[2])
        self.assertLess(self.sets[0], self.sets[1])
        self.assertLess(self.sets[2], self.sets[1])

    def test___div__(self):
        """operator/"""
        result = self.sets[1] / self.sets[2]
        self.assertEqual(dai.SmallSetSizet(23), result)

    def test___or__(self):
        """operator|"""
        result = self.sets[1] | self.sets[0]
        self.assertEqual(self.sets[1], result)

    def test___and__(self):
        """operator&"""
        result = self.sets[1] & self.sets[2]
        self.assertEqual(dai.SmallSetSizet(4), result)

    def test___idiv__(self):
        """operator/="""
        self.sets[1] /= self.sets[2]
        self.assertEqual(dai.SmallSetSizet(23), self.sets[1])

    def test___ior__(self):
        """operator|="""
        self.sets[1] |= self.sets[0]
        self.assertEqual(dai.SmallSetSizet(23, 4), self.sets[1])

    def test___iand__(self):
        """operator&="""
        self.sets[1] &= self.sets[2]
        self.assertEqual(dai.SmallSetSizet(4), self.sets[1])

    def test___lshift__(self):
        """operator<<"""
        self.assertTrue(self.sets[0] << self.sets[1])

    def test___rshift__(self):
        """operator>>"""
        self.assertTrue(self.sets[1] >> self.sets[0])


class VarSetTest(unittest.TestCase):

    def setUp(self):
        self.sets = [
            dai.VarSet(dai.Var(0, 3), dai.Var(1, 2)),
            dai.VarSet([dai.Var(2, 4), dai.Var(3, 5), dai.Var(4, 6), dai.Var(5, 2)]),
            ]

    def tearDown(self):
        for index in xrange(len(self.sets)):
            self.sets[index] = None
        self.sets = None

    def test_construction(self):
        self.assertEqual(2, len(self.sets[0]))
        self.assertTrue(dai.Var(0, 3) in self.sets[0])
        self.assertTrue(dai.Var(1, 2) in self.sets[0])
        self.assertEqual(4, len(self.sets[1]))
        self.assertTrue(dai.Var(2, 4) in self.sets[1])
        self.assertTrue(dai.Var(3, 5) in self.sets[1])
        self.assertTrue(dai.Var(4, 6) in self.sets[1])
        self.assertTrue(dai.Var(5, 2) in self.sets[1])

    def test_nrStates(self):
        self.assertEqual(6, self.sets[0].nrStates())
        self.assertEqual(240, self.sets[1].nrStates())


class ProbTest(unittest.TestCase):

    contents = (0.2,) * 5
    ones = (1.0,) * 5
    zeros = (0.0,) * 5
    logContents = tuple(math.log(value) for value in contents)
    expContents = tuple(math.exp(value) for value in contents)

    def setUp(self):
        self.prob = dai.Prob(5)

    def tearDown(self):
        self.prob = None

    def test_p(self):
        self.assertEqual(ProbTest.contents, self.prob.p())

    def test_get_set(self):
        self.assertAlmostEqual(0.2, self.prob.get(3))
        self.prob.set(3, 2.45292)
        self.assertAlmostEqual(2.45292, self.prob.get(3))

    def test_get_bounds(self):
        with self.assertRaises(IndexError):
            self.prob.get(-1)
        with self.assertRaises(IndexError):
            self.prob.get(5)

    def test_set_bounds(self):
        with self.assertRaises(IndexError):
            self.prob.set(-1, 0.5)
        with self.assertRaises(IndexError):
            self.prob.set(5, 0.5)

    def test___getitem_____setitem__(self):
        self.assertAlmostEqual(0.2, self.prob[3])
        self.prob[3] = 2.45292
        self.assertAlmostEqual(2.45292, self.prob[3])

    def test_size(self):
        self.assertEqual(5, self.prob.size())

    def test___len__(self):
        self.assertEqual(5, len(self.prob))

    def test_entropy(self):
        self.assertAlmostEqual(1.6094379124341005, self.prob.entropy())

    def test_max_min_maxAbs(self):
        self.prob[1] = -2.0
        self.prob[2] = 0.1
        self.prob[4] = 1.6
        self.assertAlmostEqual(-2.0, self.prob.min())
        self.assertAlmostEqual(1.6, self.prob.max())
        self.assertAlmostEqual(2.0, self.prob.maxAbs())

    def test_sum_sumAbs(self):
        self.prob[3] = -0.2
        self.assertAlmostEqual(0.6, self.prob.sum())
        self.assertAlmostEqual(1.0, self.prob.sumAbs())

    def test_hasNaNs(self):
        self.assertFalse(self.prob.hasNaNs())
        self.prob[0] = float('nan')
        self.assertTrue(self.prob.hasNaNs())

    def test_hasNegatives(self):
        self.assertFalse(self.prob.hasNegatives())
        self.prob[0] = -1.0
        self.assertTrue(self.prob.hasNegatives())

    def test_argmax(self):
        self.prob[1] = 2.0
        self.assertEqual((1, 2.0), self.prob.argmax())

    def test_draw(self):
        index = self.prob.draw()
        self.assertEqual(int, type(index))
        self.assertGreaterEqual(index, 0)
        self.assertLess(index, 5)

    def test___lt__(self):
        other = dai.Prob(4)
        self.assertLess(self.prob, other)

    def test___eq__(self):
        other = dai.Prob(5)
        self.assertEqual(other, self.prob)

    def test___neg__(self):
        self.assertEqual((-0.2,) * 5, (-self.prob).p())

    def test_abs(self):
        self.assertEqual(ProbTest.contents, self.prob.abs().p())

    def test_exp(self):
        self.assertEqual(ProbTest.expContents, self.prob.exp().p())

    def test_log(self):
        self.assertEqual(ProbTest.logContents, self.prob.log().p())
        probZeros = dai.Prob(5, 0.0)
        self.assertEqual(ProbTest.zeros, probZeros.log(zero=True).p())

    def test_inverse(self):
        self.assertEqual((5.0,) * 5, self.prob.inverse().p())
        probZeros = dai.Prob(5, 0.0)
        self.assertEqual(ProbTest.zeros, probZeros.inverse(zero=True).p())

    def test_normalized(self):
        self.assertEqual(ProbTest.contents, self.prob.normalized(dai.ProbNormType.NORMPROB).p())
        self.assertEqual(ProbTest.ones, self.prob.normalized(dai.ProbNormType.NORMLINF).p())

    def test_randomize(self):
        for num in self.prob.randomize().p():
            self.assertGreaterEqual(num, 0.0)
            self.assertLess(num, 1.0)

    def test_setUniform(self):
        self.prob.randomize()
        self.assertEqual(ProbTest.contents, self.prob.setUniform().p())

    def test_takeAbs(self):
        self.assertEqual(ProbTest.contents, (-self.prob).takeAbs().p())

    def test_takeAbs(self):
        self.assertEqual(ProbTest.expContents, self.prob.takeExp().p())

    def test_takeLog(self):
        self.assertEqual(ProbTest.logContents, self.prob.takeLog().p())
        probZeros = dai.Prob(5, 0.0)
        self.assertEqual(ProbTest.zeros, probZeros.takeLog(zero=True).p())

    def test_normalize(self):
        self.prob.normalize(dai.ProbNormType.NORMPROB)
        self.assertEqual(ProbTest.contents, self.prob.p())
        self.prob.normalize(dai.ProbNormType.NORMLINF)
        self.assertEqual(ProbTest.ones, self.prob.p())

    def test_fill(self):
        self.assertEqual(ProbTest.ones, self.prob.fill(1.0).p())

    def test___add__(self):
        """operator+"""
        self.assertEqual(ProbTest.ones, (self.prob + 0.8).p())
        self.assertEqual(ProbTest.ones, (self.prob + dai.Prob(5, 0.8)).p())

    def test___sub__(self):
        """operator-"""
        self.assertEqual(ProbTest.zeros, (self.prob - 0.2).p())
        self.assertEqual(ProbTest.zeros, (self.prob - dai.Prob(5, 0.2)).p())

    def test___mul__(self):
        """operator*"""
        self.assertEqual(ProbTest.ones, (self.prob * 5.0).p())
        self.assertEqual(ProbTest.ones, (self.prob * dai.Prob(5, 5.0)).p())

    def test___div__(self):
        """operator/"""
        expected = (0.1,) * 5
        self.assertEqual(expected, (self.prob / 2.0).p())
        self.assertEqual(expected, (self.prob / dai.Prob(5, 2.0)).p())

    def test___xor__(self):
        """operator^"""
        expected = (0.2 ** 2.0,) * 5
        self.assertEqual(expected, (self.prob ^ 2.0).p())
        self.assertEqual(expected, (self.prob ^ dai.Prob(5, 2.0)).p())

    def test___iadd__(self):
        """operator+="""
        self.prob += 0.8
        self.assertEqual(ProbTest.ones, self.prob.p())
        self.prob += dai.Prob(5)
        self.assertEqual((1.2,) * 5, self.prob.p())

    def test___isub__(self):
        """operator-="""
        self.prob -= 0.2
        self.assertEqual(ProbTest.zeros, self.prob.p())
        self.prob -= dai.Prob(5)
        self.assertEqual((-0.2,) * 5, self.prob.p())

    def test___imul__(self):
        """operator*="""
        self.prob *= 5.0
        self.assertEqual(ProbTest.ones, self.prob.p())
        self.prob *= dai.Prob(5)
        self.assertEqual(ProbTest.contents, self.prob.p())

    def test___idiv__(self):
        """operator/="""
        self.prob /= 2.0
        self.assertEqual((0.1,) * 5, self.prob.p())
        self.prob /= dai.Prob(5)
        self.assertEqual((0.5,) * 5, self.prob.p())

    def test___ixor__(self):
        """operator^="""
        self.prob ^= 2.0
        self.assertEqual((0.2 ** 2.0,) * 5, self.prob.p())
        self.prob ^= dai.Prob(5)
        self.assertEqual(((0.2 ** 2.0) ** 0.2,) * 5, self.prob.p())

    def test_divided_by(self):
        self.assertEqual(ProbTest.ones, self.prob.divided_by(dai.Prob(5)).p())
        self.assertEqual(ProbTest.ones, self.prob.divided_by(dai.Prob(5)).p())

    def test_divide(self):
        self.assertEqual(ProbTest.ones, self.prob.divide(dai.Prob(5)).p())

# TODO Factor tests
