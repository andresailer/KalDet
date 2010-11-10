###############################################################################
# cmake module for finding ROOT
#
# requires:
#   MacroCheckPackageLibs.cmake for checking package libraries
#
# Following cmake variables are returned by this module:
#
#   ROOT_FOUND              : set to TRUE if ROOT found
#       If FIND_PACKAGE is called with REQUIRED and COMPONENTS arguments
#       ROOT_FOUND is only set to TRUE if ALL components are found.
#       If REQUIRED is NOT set components may or may not be available
#
#   ROOT_LIBRARIES          : list of ROOT libraries (NOT including COMPONENTS)
#   ROOT_INCLUDE_DIRS       : list of paths to be used with INCLUDE_DIRECTORIES
#   ROOT_LIBRARY_DIRS       : list of paths to be used with LINK_DIRECTORIES
#   ROOT_COMPONENT_LIBRARIES    : list of ROOT component libraries
#   ROOT_${COMPONENT}_FOUND     : set to TRUE or FALSE for each library
#   ROOT_${COMPONENT}_LIBRARY   : path to individual libraries
#   
#
#   Please note that by convention components should be entered exactly as
#   the library names, i.e. the component name equivalent to the library
#   $ROOTSYS/lib/libMathMore.so should be called MathMore and NOT:
#       mathmore or Mathmore or MATHMORE
#
#   However to follow the usual cmake convention it is agreed that the
#   ROOT_${COMPONENT}_FOUND and ROOT_${COMPONENT}_LIBRARY variables are ALL
#   uppercase, i.e. the MathMore component returns: ROOT_MATHMORE_FOUND and
#   ROOT_MATHMORE_LIBRARY NOT ROOT_MathMore_FOUND or ROOT_MathMore_LIBRARY
#
#
# The additional ROOT components should be defined as follows:
# FIND_PACKAGE( ROOT COMPONENTS MathMore Gdml Geo ...)
#
# If components are required use:
# FIND_PACKAGE( ROOT REQUIRED COMPONENTS MathMore Gdml Geo ...)
#
# If only root is required and components are NOT required use:
# FIND_PACKAGE( ROOT REQUIRED )
# FIND_PACKAGE( ROOT COMPONENTS MathMore Gdml Geo ... QUIET )
#
# The Minuit2 component is always added for backwards compatibility.
#
# @author Jan Engels, DESY
###############################################################################


SET( CMAKE_ALLOW_LOOSE_LOOP_CONSTRUCTS TRUE )

# -- fix for backwards compatibility
IF( NOT DEFINED ROOT_DIR AND DEFINED ROOT_HOME )
    SET( ROOT_DIR "${ROOT_HOME}" )
ENDIF( NOT DEFINED ROOT_DIR AND DEFINED ROOT_HOME )

IF( NOT ROOT_FIND_QUIETLY )
    MESSAGE( STATUS "Check for ROOT: ${ROOT_DIR}" )
ENDIF( NOT ROOT_FIND_QUIETLY )

# set ROOTSYS for running root-config
IF( DEFINED ROOT_DIR )
    SET( ENV{ROOTSYS} "${ROOT_DIR}" )
ENDIF( DEFINED ROOT_DIR )

# find root-config
SET( ROOT_CONFIG ROOT_CONFIG-NOTFOUND )
FIND_PROGRAM( ROOT_CONFIG root-config PATHS ${ROOT_DIR}/bin NO_DEFAULT_PATH )
FIND_PROGRAM( ROOT_CONFIG root-config )

# find rootcint
SET( ROOT_CINT ROOT_CINT-NOTFOUND )
FIND_PROGRAM( ROOT_CINT rootcint PATHS ${ROOT_DIR}/bin NO_DEFAULT_PATH )
FIND_PROGRAM( ROOT_CINT rootcint )

IF( NOT ROOT_FIND_QUIETLY )
    MESSAGE( STATUS "Check for ROOT_CONFIG: ${ROOT_CONFIG}" )
    MESSAGE( STATUS "Check for ROOT_CINT: ${ROOT_CINT}" )
ENDIF()


IF( ROOT_CONFIG )

    # ==============================================
    # ===          ROOT_INCLUDE_DIR              ===
    # ==============================================

    # get include dir from root-config output
    EXECUTE_PROCESS( COMMAND "${ROOT_CONFIG}" --incdir
        OUTPUT_VARIABLE _inc_dir
        RESULT_VARIABLE _exit_code
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    IF( NOT _exit_code EQUAL 0 )
        # clear _inc_dir if root-config exits with error
        # it might contain garbage
        SET( _inc_dir )
    ENDIF()


    SET( ROOT_INCLUDE_DIRS ROOT_INCLUDE_DIRS-NOTFOUND )
    MARK_AS_ADVANCED( ROOT_INCLUDE_DIRS )

    FIND_PATH( ROOT_INCLUDE_DIRS
        NAMES TH1.h
        PATHS ${ROOT_DIR}/include ${_inc_dir}
        NO_DEFAULT_PATH
    )



    # ==============================================
    # ===            ROOT_LIBRARIES              ===
    # ==============================================

    # get library dir from root-config output
    EXECUTE_PROCESS( COMMAND "${ROOT_CONFIG}" --libdir
        OUTPUT_VARIABLE ROOT_LIBRARY_DIR
        RESULT_VARIABLE _exit_code
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    IF( NOT _exit_code EQUAL 0 )
        # clear ROOT_LIBRARY_DIR if root-config exits with error
        # it might contain garbage
        SET( ROOT_LIBRARY_DIR )
    ENDIF()



    # ========== standard root libraries =================

    # standard root libraries (without components)
    SET( _root_libnames )

    # get standard root libraries from 'root-config --libs' output
    EXECUTE_PROCESS( COMMAND "${ROOT_CONFIG}" --noauxlibs --libs
        OUTPUT_VARIABLE _aux
        RESULT_VARIABLE _exit_code
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    IF( _exit_code EQUAL 0 )
        
        # create a list out of the output
        SEPARATE_ARGUMENTS( _aux )

        # remove first item -L compiler flag
        LIST( REMOVE_AT _aux 0 )

        FOREACH( _lib ${_aux} )

            # extract libnames from -l compiler flags
            STRING( REGEX REPLACE "^-.(.*)$" "\\1" _libname "${_lib}")

            # fix for some root-config versions which export -lz even if using --noauxlibs
            IF( NOT _libname STREQUAL "z" )

                # append all library names into a list
                LIST( APPEND _root_libnames ${_libname} )

            ENDIF()

        ENDFOREACH()

    ENDIF()



    # ========== additional root components =================

    # FIXME DEPRECATED
    # append components defined in the variable ROOT_USE_COMPONENTS
    IF( DEFINED ROOT_USE_COMPONENTS )
        LIST( APPEND ROOT_FIND_COMPONENTS ${ROOT_USE_COMPONENTS} )
    ENDIF()

    # FIXME DEPRECATED
    # Minuit2 is always included (for backwards compatibility )
    LIST( FIND ROOT_FIND_COMPONENTS "Minuit2" _aux )
    IF( ${_aux} LESS 0 )
        LIST( APPEND ROOT_FIND_COMPONENTS Minuit2 )
    ENDIF()



    # ---------- libraries --------------------------------------------------------
    INCLUDE( MacroCheckPackageLibs )

    SET( ROOT_LIB_SEARCH_PATH ${ROOT_LIBRARY_DIR} )

    # only standard libraries should be passed as arguments to CHECK_PACKAGE_LIBS
    # additional components are set by cmake in variable PKG_FIND_COMPONENTS
    # first argument should be the package name
    CHECK_PACKAGE_LIBS( ROOT ${_root_libnames} )




    # ====== DL LIBRARY ==================================================
    # workaround for cmake bug in 64 bit:
    # see: http://public.kitware.com/mantis/view.php?id=10813
    IF( CMAKE_SIZEOF_VOID_P EQUAL 8 )
        FIND_LIBRARY( DL_LIB NAMES ${CMAKE_DL_LIBS} dl PATHS /usr/lib64 /lib64 NO_DEFAULT_PATH )
    ENDIF( CMAKE_SIZEOF_VOID_P EQUAL 8 )

    FIND_LIBRARY( DL_LIB NAMES ${CMAKE_DL_LIBS} dl )

    IF( NOT ROOT_FIND_QUIETLY )
        MESSAGE( STATUS "Check for libdl.so: ${DL_LIB}" )
    ENDIF()

ENDIF( ROOT_CONFIG )

# Threads library
#FIND_PACKAGE( Threads REQUIRED)


# ---------- final checking ---------------------------------------------------
INCLUDE( FindPackageHandleStandardArgs )
# set ROOT_FOUND to TRUE if all listed variables are TRUE and not empty
# ROOT_COMPONENT_VARIABLES will be set if FIND_PACKAGE is called with REQUIRED argument
FIND_PACKAGE_HANDLE_STANDARD_ARGS( ROOT DEFAULT_MSG ROOT_INCLUDE_DIRS ROOT_LIBRARIES ${ROOT_COMPONENT_VARIABLES} DL_LIB )

IF( ROOT_FOUND )
    LIST( APPEND ROOT_LIBRARIES ${DL_LIB} )
    # FIXME DEPRECATED
    SET( ROOT_DEFINITIONS "-DUSEROOT -DUSE_ROOT -DMARLIN_USE_ROOT" )
    MARK_AS_ADVANCED( ROOT_DEFINITIONS )

    # file including MACROS for generating root dictionary sources
    GET_FILENAME_COMPONENT( _aux ${CMAKE_CURRENT_LIST_FILE} PATH )
    SET( ROOT_DICT_MACROS_FILE ${_aux}/MacroRootDict.cmake )

ENDIF( ROOT_FOUND )

# ---------- cmake bug ?! -----------------------------------------------------
# ROOT_FIND_REQUIRED is not reset between FIND_PACKAGE calls, i.e. the following
# code fails when geartgeo component not available: (not tested in cmake 2.8)
# FIND_PACKAGE( ROOT REQUIRED )
# FIND_PACKAGE( ROOT COMPONENTS geartgeo QUIET )
SET( ROOT_FIND_REQUIRED )

