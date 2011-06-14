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
 * Python is the target language, but support for Octave may be
 * reincorporated later, especially if someone with Octave experience
 * wants to contribute or Joris thinks it is important enough to have
 * Aubrey work on it.
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

%module dai

/* Include the following headers for compilation.  (Swig just inserts
 * the following block verbatim into the generated wrapper code, not the
 * API.)
 */
%header
%{
#include <dai/var.h>
#include <dai/smallset.h>
#include <dai/varset.h>
%}

/* Ignore all C++ output operators because Python uses a different
 * output paradigm.  This ignores some potentially useful operators
 * (e.g. bool dai::SmallSet<T>::operator<<(const SmallSet & x) const),
 * but those can be included as needed.  (They would need to be renamed
 * anyway.)
 */
%ignore operator<<;

/****************************************
 * Var
 ****************************************/

/* Ignore the following functions because they return size_t &, which is
 * a pointless reference to a basic type for Python.  Allow the const
 * versions to persist instead.
 */
%ignore dai::Var::label();
%ignore dai::Var::states();

// Bring class Var into the API
%include <dai/var.h>

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
 * http://www.swig.org/Doc2.0/SWIGPlus.html#SWIGPlus_nn17.  Maybe a bug
 * or a documentation version discrepancy (2.0.4 vs. 2.0.1).
 *
 * However, it appears that operators that are defined as members of a
 * class are preserved despite the global nature of the following
 * ignores.  If that is true, these ignores should be harmless as all
 * friend operators will have to be brought in specially anyway.
 */
%ignore operator==;
%ignore operator!=;
%ignore operator<;

/* Bring in class SmallSet.  However, since it is a template class, it
 * must be instantiated before Swig includes it in the API.
 */
%include <dai/smallset.h>

// Make the set comparison operators ignored above available as class members
%extend dai::SmallSet {
  SmallSet operator==(const SmallSet & x) const {
    return (*$self) == x;
  }

  SmallSet operator!=(const SmallSet & x) const {
    return (*$self) != x;
  }

  SmallSet operator<(const SmallSet & x) const {
    return (*$self) < x;
  }
}

// Instantiate SmallSet as a set of integers
%template(SmallSetInt) dai::SmallSet<size_t>;

/****************************************
 * VarSet
 ****************************************/

/* The following template is needed for Swig to know about
 * SmallSet<Var>, but it does not need to be included in the API because
 * VarSet supersedes it.  (By giving it an empty template name, Swig
 * leaves it out of the API.)
 */
%template() dai::SmallSet<dai::Var>;
%include <dai/varset.h>




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
