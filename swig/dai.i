/*  This file is part of libDAI - http://www.libdai.org/
 *
 *  libDAI is licensed under the terms of the GNU General Public License version
 *  2, or (at your option) any later version. libDAI is distributed without any
 *  warranty. See the file COPYING for more details.
 *
 *  Copyright (C) 2009  Patrick Pletscher  [pletscher at inf dot ethz dot ch]
 *                2009  Joris Mooij        [joris dot mooij at libdai dot org]
 *                2011  Aubrey Barnard     [aubrey dot f dot barnard at gmail dot com]
 */

/* This file targets Swig version 2.0.1, but later versions should work
 * as well.
 *
 * Python (version >= 2.6) is the target language, but older Pythons can
 * be supported as requested.  Support for Octave may be reincorporated
 * later, especially if someone with Octave experience wants to
 * contribute or Joris thinks it is important enough to have Aubrey work
 * on it.
 *
 * Example Swig command line (from this directory):
 *
 * $ swig -Wall -python -c++ -I../include dai.i
 *
 * This file is organized in rough order of prerequisites, that is, from
 * most basic to most advanced.
 *
 * Aubrey wishes to profusely comment this file with the how and why of
 * Swig and libDAI so that future use and maintenance is easier.
 */

/*
 * TODO handle dai::Exceptions
 * TODO make instantiated vector types module-private? e.g. "_VectorVar" not "VectorVar"
 * TODO enable TProb(Python sequence) constructor
 * TODO see if there is a way to define the Python enums in terms of the C++ enum values
 */

%module dai

// Include documentation of full function signatures
%feature("autodoc", "1");

/* Include the following headers for compilation.  (Swig just inserts
 * the following block verbatim into the generated wrapper code, not the
 * API.)
 */
%header
%{
#include <dai/util.h>
#include <dai/var.h>
#include <dai/smallset.h>
#include <dai/varset.h>
#include <dai/prob.h>
#include <dai/factor.h>
%}

/* Facilitate error handling for added C/C++ code.  Create a buffer for
 * error messages used to initialize exceptions.  Bring in snprintf for
 * assembling error messages.  (I considered using the more
 * C++-appropriate stringstream to create each error message, but this
 * approach will be more brief.)
 */
%{
#include <cstdio>
#include <string>

#define DAISWIG_ERROR_MESSAGE_MAX_SIZE 256

static char daiswig_error_message[DAISWIG_ERROR_MESSAGE_MAX_SIZE];
%}

// Evidently Swig doesn't define ssize_t by default so include it here
typedef long ssize_t;

/* Include Swig adaptors for STL data structures.  Hopefully it will
 * help with a number of small problems and allow access to more of the
 * library functionality (i.e. interact better with the
 * functions/methods that take/return STL data structures).
 */
%include <std_vector.i>  // Needed for passing Python lists as std::vectors
%include <std_pair.i>  // Needed for TProb::argmax()

/* Ignore all C++ output operators because Python uses a different
 * output paradigm.  This ignores some potentially useful operators
 * (e.g. bool dai::SmallSet<T>::operator<<(const SmallSet & x) const),
 * but those can be included as needed.  (They would need to be renamed
 * anyway.)
 *
 * (I tried to limit ignoring operator<< to just the dai namespace
 * and/or to declarations where the first argument is std::ostream&, but
 * Swig won't do it despite indications in the manual that it should
 * work.  (http://www.swig.org/Doc2.0/SWIG.html#SWIG_rename_ignore,
 * http://www.swig.org/Doc2.0/SWIGPlus.html#SWIGPlus_ambiguity_resolution_renaming)
 * Maybe related to bug 2218834?)
 */
%ignore operator<<;

/****************************************
 * Util, Exceptions
 ****************************************
 *
 * Most of the contents of util.h aren't appropriate for inclusion into
 * the API.  Just import it and manually (re)define the bits that are
 * important to the API.
 *
 * Manually mirror exceptions.h because it will provide more idiomatic
 * funcionality (no checking of codes, unified conversion of C++
 * exceptions to Python exceptions).
 */

%import <dai/util.h>

%pythoncode {
class ProbNormType(object):
    """Mirror of dai::ProbNormType enumeration."""
    NORMPROB, NORMLINF = range(2)

class ProbDistType(object):
    """Mirror of dai::ProbDistType enumeration."""
    DISTL1, DISTLINF, DISTTV, DISTKL, DISTHEL = range(5)

class Exception(Exception):
    """Base of all libDAI exceptions."""
    pass

class NotImplementedException(Exception):
    pass
}

/****************************************
 * Var
 ****************************************/

/* Ignore the following functions because they return size_t &, which is
 * a pointless reference to a basic type for Python.  Allow the const
 * versions to persist instead.
 */
%ignore dai::Var::label();
%ignore dai::Var::states();

// Define class Var and bring it into the API
%include <dai/var.h>

// Var string representation
%extend dai::Var {
  %pythoncode {
    def __repr__(self):
        return 'Var({0}, {1})'.format(self.label(), self.states())
  }
}

/****************************************
 * SmallSet<T>
 ****************************************
 *
 * SmallSet<T> is an inheritance prerequisite for VarSet (VarSet is a
 * SmallSet<Var>) and it is also used in bipgraph.h, dag.h,
 * factorgraph.h, and graph.h where it is always SmallSet<size_t>.
 */

// Ignore mutable accessors (const versions are preserved)
%ignore dai::SmallSet::elements();
%ignore dai::SmallSet::front();
%ignore dai::SmallSet::back();
// Ignore mutable iterators (const versions are preserved)
%ignore dai::SmallSet::begin();
%ignore dai::SmallSet::end();
%ignore dai::SmallSet::rbegin();
%ignore dai::SmallSet::rend();

/* The following operators would not need to be ignored if they were
 * implemented as class members rather than friends as Swig can
 * automatically handle comparison operators as Python class members.
 * However, they are still useful, so they are brought into the class
 * through extension below.
 *
 * I have no clue why "operator==" works but "dai::operator==" does not,
 * especially given
 * http://www.swig.org/Doc2.0/SWIGPlus.html#SWIGPlus_nn17.  Maybe
 * related to bug 2218834?
 *
 * However, it appears that operators that are defined as members of a
 * class are preserved despite the global nature of the following
 * ignores.  If that is true, these ignores should be harmless as all
 * friend operators will have to be brought in specially anyway.
 */
%ignore operator==;
%ignore operator!=;
%ignore operator<;

/* Define class SmallSet.  However, since it is a template class, it
 * must be instantiated before Swig includes it in the API.
 */
%include <dai/smallset.h>

%extend dai::SmallSet {
  /* Make a "Swig constructor" that will accept a Python list (via
   * std:vector typemaps).  See
   * http://www.swig.org/Doc2.0/SWIG.html#SWIG_adding_member_functions
   * for more information.
   */ 
  SmallSet(const std::vector<T> & elements) {
    dai::SmallSet<T> * set = new dai::SmallSet<T>(elements.begin(), elements.end(), elements.size());
    return set;
  }

  // Make the set comparison operators ignored above available as class members
  bool operator==(const SmallSet & x) const {
    return (*$self) == x;
  }

  bool operator!=(const SmallSet & x) const {
    return (*$self) != x;
  }

  bool operator<(const SmallSet & x) const {
    return (*$self) < x;
  }

  // Make SmallSet act a bit more like a Python set
  %pythoncode {
    __len__ = size
    __contains__ = contains
    add = insert
    remove = erase
  }
}

// Instantiate std::vector for use with SmallSetSizet
%template(VectorSizet) std::vector<size_t>;

// Make SmallSet.size() return an integer
%apply size_t { std::vector<size_t>::size_type };

// Instantiate SmallSet as a set of (positive) integers
%template(SmallSetSizet) dai::SmallSet<size_t>;

/****************************************
 * VarSet
 ****************************************/

// Instantiate std::vector for use with _SmallSetVar (and VarSet)
%template(VectorVar) std::vector<dai::Var>;

// Make SmallSet.size() return an integer
%apply size_t { std::vector<dai::Var>::size_type };
// Make VarSet.nrStates() return a float
%apply double { long double };

/* The following template is needed for Swig to know about
 * SmallSet<Var>, but it does not need to be included in the API because
 * VarSet supersedes it.  Use a leading underscore to indicate that the
 * class is private to the module.  I tried leaving the name out,
 * whereby Swig leaves it out of the API, but that broke inheritance in
 * Python (VarSet was not a SmallSet).
 */
%template(_SmallSetVar) dai::SmallSet<dai::Var>;
// Define class VarSet and bring it into the API
%include <dai/varset.h>

%extend dai::VarSet {
  /* Make a "Swig constructor" that will accept a Python list (via
   * std:vector typemaps).
   */ 
  VarSet(const std::vector<dai::Var> & elements) {
    dai::SmallSet<dai::Var> * set = new dai::SmallSet<dai::Var>(elements.begin(), elements.end(), elements.size());
    dai::VarSet * varset = new dai::VarSet(*set);
    delete set;
    return varset;
  }
}

/****************************************
 * Prob
 ****************************************/

// Ignore operators Python cannot handle directly
%ignore dai::TProb::operator[];
// Ignore mutable accessors (const versions are preserved)
%ignore dai::TProb::p();
// Ignore mutable iterators (const versions are preserved)
%ignore dai::TProb::begin();
%ignore dai::TProb::end();
%ignore dai::TProb::rbegin();
%ignore dai::TProb::rend();

// Ignore functions involving operators
%ignore dai::TProb::innerProduct;
%ignore dai::TProb::accumulateSum;
%ignore dai::TProb::accumulateMax;
%ignore dai::TProb::pwUnaryTr;
%ignore dai::TProb::pwUnaryOp;
%ignore dai::TProb::pwBinaryTr;
%ignore dai::TProb::pwBinaryOp;

// Ignore get/set so they can be redefined with memory-safe versions
%ignore dai::TProb::get;
%ignore dai::TProb::set;

// Define class TProb
%include <dai/prob.h>

// Handle exceptions from TProb::normalized
//%exception dai::TProb::normalized {
//  try {
//    $action
//  } catch (dai::Exception & e) {
//
//  }
//}

%extend dai::TProb {
  /* Replace get/set with memory-safe versions.  It would be nice to be
   * able to just redefine get/set in terms of std::vector::at but _p is
   * private so we have to do things ourselves (the extensions appear in
   * the scope of the API, not in the scope of the original C++ class).
   * Don't name them with leading underscores or the Python help system
   * will ignore them.
   */
  T get_(ssize_t index) const throw(std::out_of_range) {
    if (index < 0 || index >= (ssize_t) $self->size()) {
      // Assemble the error message
      snprintf(daiswig_error_message, DAISWIG_ERROR_MESSAGE_MAX_SIZE, "Index out of range: %zd", index);
      throw std::out_of_range(std::string(daiswig_error_message, DAISWIG_ERROR_MESSAGE_MAX_SIZE));
    }
    return $self->get(index);
  }

  void set_(ssize_t index, T value) throw(std::out_of_range) {
    if (index < 0 || index >= (ssize_t) $self->size()) {
      // Assemble the error message
      snprintf(daiswig_error_message, DAISWIG_ERROR_MESSAGE_MAX_SIZE, "Index out of range: %zd", index);
      throw std::out_of_range(std::string(daiswig_error_message, DAISWIG_ERROR_MESSAGE_MAX_SIZE));
    }
    $self->set(index, value);
  }

  /* Make operator[] available to Python as a convenience.  Define
   * get/set to call the memory-safe versions.  Define __len__ for
   * idiomatic behavior.
   */
  %pythoncode {
    def __getitem__(self, index):
        return self.get_(index)

    def __setitem__(self, index, value):
        self.set_(index, value)

    __len__ = size
    get = get_
    set = set_
  }
}

/* Instantiate std::vector<double> to enable the TProb(const
 * std::vector<S> & v) constructor which will, in turn, enable TProb to
 * be constructed from a Python sequence.  Use the name VectorFloat
 * because "float" is idiomatic to Python.
 */
%template(VectorFloat) std::vector<dai::Real>;

/* Instantiate std::pair<size_t, dai::Real> to enable an idiomatic
 * return value for TProb::argmax().
 */
%template(PairSizetFloat) std::pair<size_t, dai::Real>;

// Instantiate TProb for use with floating point numbers (includes it in the API)
%template(Prob) dai::TProb<dai::Real>;

/****************************************
 * Factor
 ****************************************/

// Ignore operators Python cannot handle directly
%ignore dai::TFactor::operator[];
// Ignore mutable accessors (const versions are preserved)
%ignore dai::TFactor::p();
%ignore dai::TFactor::vars();

// Define class TFactor
%include <dai/factor.h>


%template(Factor) dai::TFactor<dai::Real>;




/****************************************
 * All the previous code to keep until its functionality is replicated.
 ****************************************/

//%module dai
//
//%{
//#include "../include/dai/var.h"
//#include "../include/dai/smallset.h"
//#include "../include/dai/varset.h"
//#include "../include/dai/prob.h"
//#include "../include/dai/factor.h"
//#include "../include/dai/graph.h"
//#include "../include/dai/bipgraph.h"
//#include "../include/dai/factorgraph.h"
//#include "../include/dai/util.h"
//%}
//
//%ignore dai::TProb::operator[];
//%ignore dai::TFactor::operator[];
//
//%ignore dai::Var::label() const;
//%ignore dai::Var::states() const;
//
//%include "../include/dai/util.h"
//%include "../include/dai/var.h"
//%include "../include/dai/smallset.h"
//%template(SmallSetVar) dai::SmallSet< dai::Var >;
//%include "../include/dai/varset.h"
//%extend dai::VarSet {
//        inline void append(const dai::Var &v) { (*self) |= v; }   /* for python, octave */
//};
//
//%include "../include/dai/prob.h"
//%template(Prob) dai::TProb<dai::Real>;
//%extend dai::TProb<dai::Real> {
//        inline dai::Real __getitem__(int i) const {return (*self).get(i);} /* for python */
//        inline void __setitem__(int i,dai::Real d) {(*self).set(i,d);}   /* for python */
//        inline dai::Real __paren(int i) const {return (*self).get(i);}     /* for octave */
//        inline void __paren_asgn(int i,dai::Real d) {(*self).set(i,d);}  /* for octave */
//};
//%include "../include/dai/factor.h"
//%extend dai::TFactor<dai::Real> {
//        inline dai::Real __getitem__(int i) const {return (*self).get(i);} /* for python */
//        inline void __setitem__(int i,dai::Real d) {(*self).set(i,d);}   /* for python */
//        inline dai::Real __paren__(int i) const {return (*self).get(i);}     /* for octave */
//        inline void __paren_asgn__(int i,dai::Real d) {(*self).set(i,d);}  /* for octave */
//};
//
//%template(Factor) dai::TFactor<dai::Real>;
//%include "../include/dai/graph.h"
//%include "../include/dai/bipgraph.h"
//%include "../include/dai/factorgraph.h"
//%include "std_vector.i"
//// TODO: typemaps for the vectors (input/output python arrays)
//%inline{
//typedef std::vector<dai::Factor> VecFactor;
//typedef std::vector< VecFactor > VecVecFactor;
//}
//%template(VecFactor) std::vector< dai::Factor >;
//%template(VecVecFactor) std::vector< VecFactor >;
//
//%include "../include/dai/index.h"
//%extend dai::multifor {
//    inline size_t __getitem__(int i) const {
//        return (*self)[i];
//    }
//    inline void next() {
//        return (*self)++;
//    }
//};
