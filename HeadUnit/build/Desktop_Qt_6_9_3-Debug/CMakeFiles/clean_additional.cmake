# Additional clean files
cmake_minimum_required(VERSION 3.16)

if("${CONFIG}" STREQUAL "" OR "${CONFIG}" STREQUAL "Debug")
  file(REMOVE_RECURSE
  "CMakeFiles/HeadUnitApp_autogen.dir/AutogenUsed.txt"
  "CMakeFiles/HeadUnitApp_autogen.dir/ParseCache.txt"
  "HeadUnitApp_autogen"
  )
endif()
