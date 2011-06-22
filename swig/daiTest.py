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

    def test_operatorLess(self):
        self.assertLess(self.vars[0], self.vars[1])

    def test_operatorGreater(self):
        self.assertGreater(self.vars[1], self.vars[0])

    def test_operatorLessEqual(self):
        self.assertLessEqual(self.vars[0], self.vars[1])
        self.assertLessEqual(self.vars[0], dai.Var(0, 5))

    def test_operatorGreaterEqual(self):
        self.assertGreaterEqual(self.vars[1], self.vars[0])
        self.assertGreaterEqual(self.vars[1], dai.Var(1, 6))

    def test_operatorEqual(self):
        self.assertEqual(self.vars[0], dai.Var(0, 5))

    def test_operatorNotEqual(self):
        self.assertNotEqual(self.vars[0], self.vars[1])

    def test_repr(self):
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

    def test_elements(self):
        self.assertEqual((), self.sets[0].elements())
        self.assertEqual((4, 23), self.sets[1].elements())
        self.assertEqual(tuple(xrange(10)), self.sets[2].elements())

    def test___nonzero__(self):
        self.assertFalse(self.sets[0])
        self.assertTrue(self.sets[1])
        self.assertTrue(self.sets[2])

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

    def test_intersects(self):
        self.assertTrue(self.sets[1].intersects(self.sets[1]))
        self.assertTrue(self.sets[1].intersects(self.sets[2]))
        self.assertFalse(self.sets[1].intersects(self.sets[0]))

    def test_insert(self):
        self.sets[0].insert(67)
        self.assertEqual(1, self.sets[0].size())
        self.assertTrue(self.sets[0].contains(67))

    def test_erase(self):
        self.sets[1].erase(4)
        self.assertEqual(1, self.sets[1].size())
        self.assertFalse(self.sets[1].contains(4))

    def test_operatorEqual(self):
        self.assertEqual(self.sets[1], dai.SmallSetSizet(4, 23))

    def test_operatorNotEqual(self):
        self.assertNotEqual(self.sets[0], self.sets[1])

    def test_operatorLess(self):
        # Lexicographic ordering (length not considered)
        self.assertLess(self.sets[0], self.sets[2])
        self.assertLess(self.sets[0], self.sets[1])
        self.assertLess(self.sets[2], self.sets[1])


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

    def setUp(self):
        self.prob = dai.Prob(5)

    def tearDown(self):
        self.prob = None

    def test_p(self):
        self.assertEqual((0.2,) * 5, self.prob.p())

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

    def test_operatorIndex(self):
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

    def test_operatorLess(self):
        other = dai.Prob(4)
        self.assertLess(self.prob, other)

    def test_operatorEqual(self):
        other = dai.Prob(5)
        self.assertEqual(other, self.prob)

    def test___neg__(self):
        self.assertEqual((-0.2,) * 5, (-self.prob).p())

    def test_abs(self):
        self.assertEqual((0.2,) * 5, self.prob.abs().p())

    def test_exp(self):
        self.assertEqual((math.exp(0.2),) * 5, self.prob.exp().p())

    def test_log(self):
        self.assertEqual((math.log(0.2),) * 5, self.prob.log().p())
        zeros = dai.Prob(3, 0.0)
        self.assertEqual((0.0,) * 3, zeros.log(zero=True).p())

    def test_inverse(self):
        self.assertEqual((5.0,) * 5, self.prob.inverse().p())
        zeros = dai.Prob(3, 0.0)
        self.assertEqual((0.0,) * 3, zeros.inverse(zero=True).p())

    def test_normalized(self):
        self.assertEqual((0.2,) * 5, self.prob.normalized(dai.ProbNormType.NORMPROB).p())
        self.assertEqual((1.0,) * 5, self.prob.normalized(dai.ProbNormType.NORMLINF).p())

    # TODO finish Prob tests

# TODO Factor tests
