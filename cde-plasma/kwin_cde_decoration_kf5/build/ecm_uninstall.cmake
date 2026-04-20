cmake_policy(VERSION 3.16)

if(NOT EXISTS "/storage01/code/c_things/cde-plasma/old-source/cde-plasma/cde-plasma/kwin_cde_decoration_kf5/build/install_manifest.txt")
    message(FATAL_ERROR "Cannot find install manifest: /storage01/code/c_things/cde-plasma/old-source/cde-plasma/cde-plasma/kwin_cde_decoration_kf5/build/install_manifest.txt")
endif()

file(READ "/storage01/code/c_things/cde-plasma/old-source/cde-plasma/cde-plasma/kwin_cde_decoration_kf5/build/install_manifest.txt" files)
string(REGEX REPLACE "\n" ";" files "${files}")
foreach(file ${files})
    message(STATUS "Uninstalling $ENV{DESTDIR}${file}")
    if(IS_SYMLINK "$ENV{DESTDIR}${file}" OR EXISTS "$ENV{DESTDIR}${file}")
        execute_process(
            COMMAND "/usr/bin/cmake" -E remove "$ENV{DESTDIR}${file}"
            RESULT_VARIABLE rm_retval
            )
        if(NOT "${rm_retval}" STREQUAL 0)
            message(FATAL_ERROR "Problem when removing $ENV{DESTDIR}${file}")
        endif()
    else()
        message(STATUS "File $ENV{DESTDIR}${file} does not exist.")
    endif()
endforeach()
