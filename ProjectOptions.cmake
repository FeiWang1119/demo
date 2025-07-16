include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


include(CheckCXXSourceCompiles)


macro(demo_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)

    message(STATUS "Sanity checking UndefinedBehaviorSanitizer, it should be supported on this platform")
    set(TEST_PROGRAM "int main() { return 0; }")

    # Check if UndefinedBehaviorSanitizer works at link time
    set(CMAKE_REQUIRED_FLAGS "-fsanitize=undefined")
    set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=undefined")
    check_cxx_source_compiles("${TEST_PROGRAM}" HAS_UBSAN_LINK_SUPPORT)

    if(HAS_UBSAN_LINK_SUPPORT)
      message(STATUS "UndefinedBehaviorSanitizer is supported at both compile and link time.")
      set(SUPPORTS_UBSAN ON)
    else()
      message(WARNING "UndefinedBehaviorSanitizer is NOT supported at link time.")
      set(SUPPORTS_UBSAN OFF)
    endif()
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    if (NOT WIN32)
      message(STATUS "Sanity checking AddressSanitizer, it should be supported on this platform")
      set(TEST_PROGRAM "int main() { return 0; }")

      # Check if AddressSanitizer works at link time
      set(CMAKE_REQUIRED_FLAGS "-fsanitize=address")
      set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=address")
      check_cxx_source_compiles("${TEST_PROGRAM}" HAS_ASAN_LINK_SUPPORT)

      if(HAS_ASAN_LINK_SUPPORT)
        message(STATUS "AddressSanitizer is supported at both compile and link time.")
        set(SUPPORTS_ASAN ON)
      else()
        message(WARNING "AddressSanitizer is NOT supported at link time.")
        set(SUPPORTS_ASAN OFF)
      endif()
    else()
      set(SUPPORTS_ASAN ON)
    endif()
  endif()
endmacro()

macro(demo_setup_options)
  option(demo_ENABLE_HARDENING "Enable hardening" ON)
  option(demo_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    demo_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    demo_ENABLE_HARDENING
    OFF)

  demo_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR demo_PACKAGING_MAINTAINER_MODE)
    option(demo_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(demo_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(demo_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(demo_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(demo_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(demo_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(demo_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(demo_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(demo_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(demo_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(demo_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(demo_ENABLE_PCH "Enable precompiled headers" OFF)
    option(demo_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(demo_ENABLE_IPO "Enable IPO/LTO" ON)
    option(demo_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(demo_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(demo_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(demo_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(demo_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(demo_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(demo_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(demo_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(demo_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(demo_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(demo_ENABLE_PCH "Enable precompiled headers" OFF)
    option(demo_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      demo_ENABLE_IPO
      demo_WARNINGS_AS_ERRORS
      demo_ENABLE_USER_LINKER
      demo_ENABLE_SANITIZER_ADDRESS
      demo_ENABLE_SANITIZER_LEAK
      demo_ENABLE_SANITIZER_UNDEFINED
      demo_ENABLE_SANITIZER_THREAD
      demo_ENABLE_SANITIZER_MEMORY
      demo_ENABLE_UNITY_BUILD
      demo_ENABLE_CLANG_TIDY
      demo_ENABLE_CPPCHECK
      demo_ENABLE_COVERAGE
      demo_ENABLE_PCH
      demo_ENABLE_CACHE)
  endif()

  demo_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (demo_ENABLE_SANITIZER_ADDRESS OR demo_ENABLE_SANITIZER_THREAD OR demo_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(demo_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(demo_global_options)
  if(demo_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    demo_enable_ipo()
  endif()

  demo_supports_sanitizers()

  if(demo_ENABLE_HARDENING AND demo_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR demo_ENABLE_SANITIZER_UNDEFINED
       OR demo_ENABLE_SANITIZER_ADDRESS
       OR demo_ENABLE_SANITIZER_THREAD
       OR demo_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${demo_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${demo_ENABLE_SANITIZER_UNDEFINED}")
    demo_enable_hardening(demo_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(demo_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(demo_warnings INTERFACE)
  add_library(demo_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  demo_set_project_warnings(
    demo_warnings
    ${demo_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(demo_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    demo_configure_linker(demo_options)
  endif()

  include(cmake/Sanitizers.cmake)
  demo_enable_sanitizers(
    demo_options
    ${demo_ENABLE_SANITIZER_ADDRESS}
    ${demo_ENABLE_SANITIZER_LEAK}
    ${demo_ENABLE_SANITIZER_UNDEFINED}
    ${demo_ENABLE_SANITIZER_THREAD}
    ${demo_ENABLE_SANITIZER_MEMORY})

  set_target_properties(demo_options PROPERTIES UNITY_BUILD ${demo_ENABLE_UNITY_BUILD})

  if(demo_ENABLE_PCH)
    target_precompile_headers(
      demo_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(demo_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    demo_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(demo_ENABLE_CLANG_TIDY)
    demo_enable_clang_tidy(demo_options ${demo_WARNINGS_AS_ERRORS})
  endif()

  if(demo_ENABLE_CPPCHECK)
    demo_enable_cppcheck(${demo_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(demo_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    demo_enable_coverage(demo_options)
  endif()

  if(demo_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(demo_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(demo_ENABLE_HARDENING AND NOT demo_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR demo_ENABLE_SANITIZER_UNDEFINED
       OR demo_ENABLE_SANITIZER_ADDRESS
       OR demo_ENABLE_SANITIZER_THREAD
       OR demo_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    demo_enable_hardening(demo_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
