include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(nimba_vision_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(nimba_vision_setup_options)
  option(nimba_vision_ENABLE_HARDENING "Enable hardening" ON)
  option(nimba_vision_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    nimba_vision_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    nimba_vision_ENABLE_HARDENING
    OFF)

  nimba_vision_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR nimba_vision_PACKAGING_MAINTAINER_MODE)
    option(nimba_vision_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(nimba_vision_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(nimba_vision_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(nimba_vision_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(nimba_vision_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(nimba_vision_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(nimba_vision_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(nimba_vision_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(nimba_vision_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(nimba_vision_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(nimba_vision_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(nimba_vision_ENABLE_PCH "Enable precompiled headers" OFF)
    option(nimba_vision_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(nimba_vision_ENABLE_IPO "Enable IPO/LTO" ON)
    option(nimba_vision_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(nimba_vision_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(nimba_vision_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(nimba_vision_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(nimba_vision_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(nimba_vision_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(nimba_vision_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(nimba_vision_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(nimba_vision_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(nimba_vision_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(nimba_vision_ENABLE_PCH "Enable precompiled headers" OFF)
    option(nimba_vision_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      nimba_vision_ENABLE_IPO
      nimba_vision_WARNINGS_AS_ERRORS
      nimba_vision_ENABLE_USER_LINKER
      nimba_vision_ENABLE_SANITIZER_ADDRESS
      nimba_vision_ENABLE_SANITIZER_LEAK
      nimba_vision_ENABLE_SANITIZER_UNDEFINED
      nimba_vision_ENABLE_SANITIZER_THREAD
      nimba_vision_ENABLE_SANITIZER_MEMORY
      nimba_vision_ENABLE_UNITY_BUILD
      nimba_vision_ENABLE_CLANG_TIDY
      nimba_vision_ENABLE_CPPCHECK
      nimba_vision_ENABLE_COVERAGE
      nimba_vision_ENABLE_PCH
      nimba_vision_ENABLE_CACHE)
  endif()

  nimba_vision_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (nimba_vision_ENABLE_SANITIZER_ADDRESS OR nimba_vision_ENABLE_SANITIZER_THREAD OR nimba_vision_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(nimba_vision_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(nimba_vision_global_options)
  if(nimba_vision_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    nimba_vision_enable_ipo()
  endif()

  nimba_vision_supports_sanitizers()

  if(nimba_vision_ENABLE_HARDENING AND nimba_vision_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR nimba_vision_ENABLE_SANITIZER_UNDEFINED
       OR nimba_vision_ENABLE_SANITIZER_ADDRESS
       OR nimba_vision_ENABLE_SANITIZER_THREAD
       OR nimba_vision_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${nimba_vision_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${nimba_vision_ENABLE_SANITIZER_UNDEFINED}")
    nimba_vision_enable_hardening(nimba_vision_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(nimba_vision_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(nimba_vision_warnings INTERFACE)
  add_library(nimba_vision_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  nimba_vision_set_project_warnings(
    nimba_vision_warnings
    ${nimba_vision_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(nimba_vision_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    nimba_vision_configure_linker(nimba_vision_options)
  endif()

  include(cmake/Sanitizers.cmake)
  nimba_vision_enable_sanitizers(
    nimba_vision_options
    ${nimba_vision_ENABLE_SANITIZER_ADDRESS}
    ${nimba_vision_ENABLE_SANITIZER_LEAK}
    ${nimba_vision_ENABLE_SANITIZER_UNDEFINED}
    ${nimba_vision_ENABLE_SANITIZER_THREAD}
    ${nimba_vision_ENABLE_SANITIZER_MEMORY})

  set_target_properties(nimba_vision_options PROPERTIES UNITY_BUILD ${nimba_vision_ENABLE_UNITY_BUILD})

  if(nimba_vision_ENABLE_PCH)
    target_precompile_headers(
      nimba_vision_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(nimba_vision_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    nimba_vision_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(nimba_vision_ENABLE_CLANG_TIDY)
    nimba_vision_enable_clang_tidy(nimba_vision_options ${nimba_vision_WARNINGS_AS_ERRORS})
  endif()

  if(nimba_vision_ENABLE_CPPCHECK)
    nimba_vision_enable_cppcheck(${nimba_vision_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(nimba_vision_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    nimba_vision_enable_coverage(nimba_vision_options)
  endif()

  if(nimba_vision_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(nimba_vision_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(nimba_vision_ENABLE_HARDENING AND NOT nimba_vision_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR nimba_vision_ENABLE_SANITIZER_UNDEFINED
       OR nimba_vision_ENABLE_SANITIZER_ADDRESS
       OR nimba_vision_ENABLE_SANITIZER_THREAD
       OR nimba_vision_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    nimba_vision_enable_hardening(nimba_vision_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
