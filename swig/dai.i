/*  This file is part of libDAI - http://www.libdai.org/
 *
 *  Copyright (c) 2006-2011, The libDAI authors. All rights reserved.
 *
 *  Use of this source code is governed by a BSD-style license that can be found in the LICENSE file.
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
 * This file is written in C++ although portions have a more C-like
 * style (e.g. when working with the Python C API).
 *
 * Aubrey wishes to profusely comment this file with the how and why of
 * Swig and libDAI so that future use and maintenance is easier.
 */

/*
 * TODO test BigInt in-typemap (TFactor, State, VarSet)
 * TODO make instantiated vector types module-private? e.g. "_VectorVar" not "VectorVar"
 * TODO enable TProb(Python sequence) constructor
 * TODO see if there is a way to define the Python enums in terms of the C++ enum values
 * TODO check that %newobject is applied where needed (and its relation to return by value)
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
#include <dai/graph.h>
#include <dai/bipgraph.h>
#include <dai/factorgraph.h>
#include <dai/properties.h>
#include <dai/daialg.h>
#include <dai/alldai.h>
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
 * Errors
 ****************************************
 *
 * Facilitate error handling for added C/C++ code.  Create a buffer for
 * error messages used to initialize exceptions.  Bring in snprintf for
 * assembling error messages.  (I considered using the more
 * C++-appropriate stringstream to create each error message, but this
 * approach will be more brief.)
 *
 * Also facilitate handling C++ exceptions by providing access to
 * exceptions in Python and providing conversion from C++ exceptions to
 * Swig/Python exceptions.
 */

%{
// Prerequisites for building error messages in C++
#include <cstdio>
#include <string>

#include <dai/exceptions.h>

// Buffer for building error messages.  Provides about 3 lines of text at 80 characters per line.
#define DAISWIG_ERROR_MESSAGE_MAX_SIZE 256
static char daiswig_error_message[DAISWIG_ERROR_MESSAGE_MAX_SIZE];

/* Python exception type object used for creating DAI Exceptions.  Only
 * access this through daiswig_getDaiExceptionType().
 */
static PyObject * daiswig_daiExceptionType = NULL;

/* Retrieves the Python DAI exception type object and caches it (like
 * lazy instantiation).  Returns a borrowed reference.  (Do not
 * decrement!)  Returns NULL if there was an error.  (If it returns
 * successfully once, it should return successfully from then on.)
 */
static PyObject * daiswig_getDaiExceptionType() {
  printf("daiswig_getDaiExceptionType\n");
  // Retrieve the type if it is not already available
  if (daiswig_daiExceptionType == NULL) {
    printf(" - Retrieving DaiException type\n");
    PyObject * daiExceptionModuleName;
    PyObject * daiExceptionModule;
    PyObject * exceptionType;

    daiExceptionModuleName = PyString_FromString("dai");  // new ref
    if (!daiExceptionModuleName)
      goto errorModuleName;

    // Import the module of exceptions
    daiExceptionModule = PyImport_Import(daiExceptionModuleName);  // new ref
    if (!daiExceptionModule)
      goto errorModule;

    // Get the particular exception type
    exceptionType = PyObject_GetAttrString(daiExceptionModule, "DaiException");  // new ref
    if (!exceptionType)
      goto errorExceptionType;
    // Check that the type is OK and then cast it
    if (PyType_Check(exceptionType)) {
      daiswig_daiExceptionType = exceptionType;
    } else {
      PyErr_SetString(PyExc_SystemError, "_daiException.Exception is not a type object.");
    }

    // Clean up
    // Do not decrement the reference to the exception type so it stays around for later use
  errorExceptionType:
    Py_DECREF(daiExceptionModule);
  errorModule:
    Py_DECREF(daiExceptionModuleName);
  }
 errorModuleName:
  // Nothing to clean up if the module name failed

  // Return the (newly) cached value
  // The variable should be NULL in the event of an error (it is only set upon success)
  return daiswig_daiExceptionType;
}

/* Convert a DAI exception to a Python exception and set the Python
 * exception.
 */
static void daiswig_handleDaiException_Python(dai::Exception & e) {
  printf("daiswig_handleDaiException_Python\n");
  // TODO? A Python exception should not already exist at this point

  // Assemble the basic information
  const char * message = e.what();
  PyObject * daiExceptionType = daiswig_getDaiExceptionType();  // borrowed ref, leave it alone
  // Variables for handling an existing exception
  PyObject * exceptionType;
  PyObject * exceptionValue;
  PyObject * exceptionTraceback;
  PyObject * exceptionString = NULL;
  const char * exceptionTypeName = "Exception";
  const char * exceptionAsCString = "Error: Too many errors! The sky is falling!";

  // If getting the DAI exception type object caused a problem create a message with both errors
  if (!daiExceptionType) {
    if (PyErr_Occurred()) {
      // Get the existing exception
      PyErr_Fetch(&exceptionType, &exceptionValue, &exceptionTraceback);
      // Convert it to a string
      if (exceptionValue) {
	exceptionString = PyObject_Str(exceptionValue);
	if (exceptionString)
	  exceptionAsCString = PyString_AsString(exceptionString);
      }
      if (exceptionType) {
	exceptionTypeName = ((PyTypeObject *) exceptionType)->tp_name;
      }
      // Restore the exception.  Let Python deal with it when the new error is raised.
      PyErr_Restore(exceptionType, exceptionValue, exceptionTraceback);
      // Create a joint message
      snprintf(daiswig_error_message, DAISWIG_ERROR_MESSAGE_MAX_SIZE,
	       "%s\n(Also, while trying to handle this:\n%s: %s)",
	       e.what(), exceptionTypeName, exceptionAsCString);
      message = daiswig_error_message;
      Py_XDECREF(exceptionString);
    }
    daiExceptionType = PyExc_RuntimeError;
  }
  PyErr_SetString(daiExceptionType, message);
}

/* Handle DAI exceptions and all descendants of std::exception.  Just
 * sets up the errors and returns nothing.
 */
static void daiswig_handleException(std::exception & exception) {
  printf("daiswig_handleException\n");
  printf(" - type name of exception passed in: %s\n - what: %s\n", typeid(exception).name(), exception.what());

  try {
    // Down cast the exception to its actual type so that the catch blocks will work
    // (See if the cast will work by first casting to a pointer.)
    if (dynamic_cast<dai::Exception *>(&exception))
      throw dynamic_cast<dai::Exception &>(exception);
    else if (dynamic_cast<std::invalid_argument *>(&exception))
      throw dynamic_cast<std::invalid_argument &>(exception);
    else if (dynamic_cast<std::domain_error *>(&exception))
      throw dynamic_cast<std::domain_error &>(exception);
    else if (dynamic_cast<std::overflow_error *>(&exception))
      throw dynamic_cast<std::overflow_error &>(exception);
    else if (dynamic_cast<std::out_of_range *>(&exception))
      throw dynamic_cast<std::out_of_range &>(exception);
    else if (dynamic_cast<std::length_error *>(&exception))
      throw dynamic_cast<std::length_error &>(exception);
    else if (dynamic_cast<std::runtime_error *>(&exception))
      throw dynamic_cast<std::runtime_error &>(exception);
    else
      throw exception;
  } catch (dai::Exception & e) {
    printf(" - catch dai::Exception\n");
    /* Future, language-specific versions can go here (with appropriate
     * conditional compilation).  Or, maybe a single function could be
     * defined by several language modules and the appropriate one
     * linked in.
     */
    daiswig_handleDaiException_Python(e);
  }
  /* Below is a copy of Swig's default handling of standard exceptions.
   * The SWIG_CATCH_STDEXCEPT doesn't work because this whole business
   * is within % { % }.
   */
  catch (std::invalid_argument & e) {
    printf(" - catch std::invalid_argument\n");
    SWIG_exception(SWIG_ValueError, e.what());
  } catch (std::domain_error & e) {
    printf(" - catch std::domain_error\n");
    SWIG_exception(SWIG_ValueError, e.what());
  } catch (std::overflow_error & e) {
    printf(" - catch std::overflow_error\n");
    SWIG_exception(SWIG_OverflowError, e.what());
  } catch (std::out_of_range & e) {
    printf(" - catch std::out_of_range\n");
    SWIG_exception(SWIG_IndexError, e.what());
  } catch (std::length_error & e) {
    printf(" - catch std::length_error\n");
    SWIG_exception(SWIG_IndexError, e.what());
  } catch (std::runtime_error & e) {
    printf(" - catch std::runtime_error\n");
    SWIG_exception(SWIG_RuntimeError, e.what());
  } catch (std::exception & e) {
    printf(" - catch std::exception\nwhat: %s\n", e.what());
    SWIG_exception(SWIG_SystemError, e.what());
  }
  /* Swig's default handling of standard exceptions almost always
   * includes "goto fail" (depending on the macro definition) so provide
   * that label here.
   */
 fail:
  return;
}
%}

/* Global exception handler.  Keep this minimal to prevent code bloat
 * (as it is added to every wrapper) and do the actual handling in a
 * separate function.
 */
%exception {
  try {
    $action
  } catch (std::exception & e) {
    daiswig_handleException(e); SWIG_fail;
    // Use SWIG_fail to fail in a language-independent way which is what SWIG_exception does.
  } catch (...) {
    SWIG_exception(SWIG_UnknownError, "daiswig: Error: Unknown exception.");
  }
}

/****************************************
 * Util, Exception, Python module header
 ****************************************
 *
 * Most of the contents of util.h aren't appropriate for inclusion into
 * the API.  Just import it (rather than include it) and manually
 * (re)define the bits that are important to the API.
 *
 * Manually mirror the classes in exceptions.h because it will provide
 * more idiomatic funcionality (no checking of codes, unified conversion
 * of C++ exceptions to Python exceptions).
 */

%import <dai/util.h>

%pythoncode {
class ProbNormType(object):
    """Mirror of dai::ProbNormType enumeration."""
    NORMPROB, NORMLINF = range(2)

class ProbDistType(object):
    """Mirror of dai::ProbDistType enumeration."""
    DISTL1, DISTLINF, DISTTV, DISTKL, DISTHEL = range(5)

class DaiException(Exception):
    """Used for all libDAI exceptions."""
    pass
}

/****************************************
 * BigInt
 ****************************************
 *
 * Typemaps for Python long <-> BigInt.
 *
 * Applies to: BigInt VarSet.nrStates(), State(const VarSet &, BigInt),
 * BigInt State::operator() (...), std::pair<size_t, BigInt>
 * boundTreeWidth(...).
 */

%{
/* Convert a Python integer or long to a BigInt.  If the value is small
 * enough just convert it to a BigInt directly (via long).  Otherwise
 * convert it to a string first and create a BigInt from the string.
 */
static dai::BigInt * daiswig_pythonLong_to_bigInt(PyObject * numberObject) {
  PyObject * pyLongRepr = PyNumber_Long(numberObject);  // as if "long(numberObject)"
  if (!pyLongRepr) {
      // Assemble the error message and throw an exception
      snprintf(daiswig_error_message, DAISWIG_ERROR_MESSAGE_MAX_SIZE, "Failed to convert Python object to a Python long object.");
      throw std::invalid_argument(std::string(daiswig_error_message, DAISWIG_ERROR_MESSAGE_MAX_SIZE));
  }
  long longRepr = PyLong_AsLong(pyLongRepr);
  Py_DECREF(pyLongRepr);
  // Check for an error.  If there was one, the value did not fit in a long, so use a string conversion.
  if (longRepr == -1 && PyErr_Occurred()) {  // FIXME: Possible bug in ignoring the exception type
    PyErr_Clear();
    PyObject * pyStringRepr = PyObject_Str(numberObject);  // as if "str(numberObject)"
    if (!pyStringRepr) {
      // Assemble the error message and throw an exception
      snprintf(daiswig_error_message, DAISWIG_ERROR_MESSAGE_MAX_SIZE, "Failed to convert Python integer object to a Python string object.");
      throw std::runtime_error(std::string(daiswig_error_message, DAISWIG_ERROR_MESSAGE_MAX_SIZE));
    }
    // The pointer returned from the following call is internal to Python and should not be deallocated
    char * stringRepr = PyString_AsString(pyStringRepr);
    Py_DECREF(pyStringRepr);
    if (!stringRepr) {
      // Assemble the error message and throw an exception
      snprintf(daiswig_error_message, DAISWIG_ERROR_MESSAGE_MAX_SIZE, "Failed to convert Python string object to a C string.");
      throw std::runtime_error(std::string(daiswig_error_message, DAISWIG_ERROR_MESSAGE_MAX_SIZE));
    }
    // Create a BigInt from a string
    return new dai::BigInt(stringRepr);
  } else {
    // Create a BigInt from a long
    return new dai::BigInt(longRepr);
  }
}

/* Convert a BigInt to a Python long.  Python longs are arbitrary
 * precision so there should not be a problem of truncation.  If the
 * value is small enough just convert it to a long directly.  Otherwise
 * convert it to a string first and have Python parse the string.
 */
static PyObject * daiswig_bigInt_to_pythonLong(const dai::BigInt & bigInt) {
  if (bigInt.fits_slong_p()) {
    return PyLong_FromLong(bigInt.get_si());
  } else {
    // 10 is the base of the integer in the following two calls
    char * stringRepr = mpz_get_str(NULL, 10, bigInt.get_mpz_t());
    PyObject * pythonLong = PyLong_FromString(stringRepr, NULL, 10);
    free(stringRepr);
    return pythonLong;
  }
}
%}

/* Typemap to check that the input argument is a Python primitive
 * integer type.
 */
%typemap(typecheck) BigInt {
  $1 = (PyInt_Check($input) || PyLong_Check($input)) ? 1 : 0;
}

/* Typemap to convert a Python integer or long to a BigInt.
 */
%typemap(in) dai::BigInt {
  $1 = daiswig_pythonLong_to_bigInt($input);
}

/* Typemap to convert a BigInt to a Python long.
 */
%typemap(out) dai::BigInt {
  $result = daiswig_bigInt_to_pythonLong($1);
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

// Ignore mutators (accessors (const versions) are preserved)
%ignore dai::SmallSet::elements();
%ignore dai::SmallSet::front();
%ignore dai::SmallSet::back();
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
// Ignore mutators (accessors (const versions) are preserved)
%ignore dai::TProb::p();
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

%extend dai::TProb {
  /* Replace get/set with memory-safe versions.  It would be nice to be
   * able to just redefine get/set in terms of std::vector::at but _p is
   * private so we have to do things ourselves (the extensions appear in
   * the scope of the API, not in the scope of the original C++ class).
   * Use ssize_t instead of the original size_t so that any Python
   * integer can be passed in.
   */
  T get(ssize_t index) const throw (std::out_of_range) {
    if (index < 0 || index >= (ssize_t) $self->size()) {
      // Assemble the error message
      snprintf(daiswig_error_message, DAISWIG_ERROR_MESSAGE_MAX_SIZE, "Index out of range: %zd", index);
      throw std::out_of_range(std::string(daiswig_error_message, DAISWIG_ERROR_MESSAGE_MAX_SIZE));
    }
    return $self->get(index);
  }

  void set(ssize_t index, T value) throw (std::out_of_range) {
    if (index < 0 || index >= (ssize_t) $self->size()) {
      // Assemble the error message
      snprintf(daiswig_error_message, DAISWIG_ERROR_MESSAGE_MAX_SIZE, "Index out of range: %zd", index);
      throw std::out_of_range(std::string(daiswig_error_message, DAISWIG_ERROR_MESSAGE_MAX_SIZE));
    }
    $self->set(index, value);
  }

  /* Make operator[] available to Python as a convenience.  Define
   * __len__ for idiomatic behavior.
   */
  %pythoncode {
    def __getitem__(self, index):
        return self.get(index)

    def __setitem__(self, index, value):
        self.set(index, value)

    __len__ = size
  }
}

/* Ignore get/set so they can be redefined with memory-safe versions.
 * The ignore has to occur after the extend for this to work without
 * renaming.
 */
%ignore dai::TProb::get;
%ignore dai::TProb::set;

// Define class TProb
%include <dai/prob.h>

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
// Ignore mutators (accessors (const versions) are preserved)
%ignore dai::TFactor::p();
%ignore dai::TFactor::vars();

// Ignore functions involving operators
%ignore dai::TFactor::binaryOp;
%ignore dai::TFactor::binaryTr;

%extend dai::TFactor {
  /* Replace get/set with memory-safe versions as for TProb.
   */
  T get(ssize_t index) const throw (std::out_of_range) {
    if (index < 0 || index >= (ssize_t) $self->nrStates()) {
      // Assemble the error message
      snprintf(daiswig_error_message, DAISWIG_ERROR_MESSAGE_MAX_SIZE, "Index out of range: %zd", index);
      throw std::out_of_range(std::string(daiswig_error_message, DAISWIG_ERROR_MESSAGE_MAX_SIZE));
    }
    return $self->get(index);
  }

  void set(ssize_t index, T value) throw (std::out_of_range) {
    if (index < 0 || index >= (ssize_t) $self->nrStates()) {
      // Assemble the error message
      snprintf(daiswig_error_message, DAISWIG_ERROR_MESSAGE_MAX_SIZE, "Index out of range: %zd", index);
      throw std::out_of_range(std::string(daiswig_error_message, DAISWIG_ERROR_MESSAGE_MAX_SIZE));
    }
    $self->set(index, value);
  }

  /* Make operator[] available to Python as a convenience.  Define
   * __len__ for idiomatic behavior.
   */
  %pythoncode {
    def __getitem__(self, index):
        return self.get(index)

    def __setitem__(self, index, value):
        self.set(index, value)

    __len__ = nrStates
  }
}

/* Ignore get/set so they can be redefined with memory-safe versions.
 * The ignore has to occur after the extend for this to work without
 * renaming.
 */
%ignore dai::TFactor::get;
%ignore dai::TFactor::set;

// Define class TFactor
%include <dai/factor.h>

// Instantiate TFactor for use with floating point numbers (includes it in the API)
%template(Factor) dai::TFactor<dai::Real>;

/****************************************
 * Neighbor, Neighbors, Edge, GraphAL
 ****************************************/

// Ignore casting operators
%ignore dai::Neighbor::operator size_t;
/* Ignore mutators (accessors (const versions) are preserved).  Just
 * ignoring "nb" ignores all four versions, so I evidently have to
 * specify overloaded methods individually to keep their const versions.
 */
%ignore dai::GraphAL::nb(size_t,size_t);
%ignore dai::GraphAL::nb(size_t);

// Define struct Neighbor, type Neighbors, type Edge, class GraphAL
%include <dai/graph.h>

// Instantiate a vector of Neighbor
%template(VectorNeighbor) std::vector<dai::Neighbor>;

/****************************************
 * BipartiteGraph
 ****************************************/

// Ignore mutators (accessors (const versions) are preserved)
%ignore dai::BipartiteGraph::nb1;
%ignore dai::BipartiteGraph::nb2;

// Define class BipartiteGraph
%include <dai/bipgraph.h>

/****************************************
 * Factor Graph
 ****************************************/

// Ignore operators Python cannot handle directly
%ignore operator>>;

/* Instantiate std::vector<dai::Factor> to enable the FactorGraph(const
 * std::vector<Factor> & P) constructor which will, in turn, enable
 * FactorGraph to be constructed from a Python sequence.
 */
%template(VectorFactor) std::vector<dai::Factor>;

// Define class FactorGraph
%include <dai/factorgraph.h>

/****************************************
 * Property, PropertySet
 ****************************************/

// Ignore getting as certain types
%ignore dai::PropertySet::getAs;
%ignore dai::PropertySet::getStringAs;

// Ignore the warning that PropertySet uses private inheritance
%warnfilter(309) dai::PropertySet;  // It doesn't work.  Same problems as above with %ignore?

// Define type PropertyKey, type PropertyValue, type Property, class PropertySet
%include <dai/properties.h>

/****************************************
 * InfAlg, DAIAlg
 ****************************************
 *
 * Eventually the specific inference algorithm classes may need to be
 * added to the API.  However, for now the factory functions newInfAlg*
 * (from alldai.h, defined below) should be sufficient.
 */

// Ignore mutators (accessors (const versions) are preserved)
%ignore dai::InfAlg::fg;

// TODO handle InfAlg.construct

// Define class InfAlg, class DAIAlg
%include <dai/daialg.h>

/****************************************
 * All DAI (newInfAlg*)
 ****************************************/

// Functions to leave out of the API
%ignore dai::parseNameProperties;
%ignore dai::readAliasesFile;

// Tell Swig that newInfAlg, newInfAlgFromString are factory functions
%newobject dai::newInfAlg;
%newobject dai::newInfAlgFromString;

/* Make sets of strings available to Python to enable an idiomatic
 * return value from builtinInfAlgNames.  Both of the includes (string,
 * set) and the template are necessary.
 */
%include "std_string.i"
%include "std_set.i"
%template(SetString) std::set<std::string>;

// TODO handle builtinInfAlgs()

// Define functions listInfAlgs, newInfAlg*
%include <dai/alldai.h>




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
