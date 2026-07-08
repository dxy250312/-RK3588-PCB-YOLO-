cmake_minimum_required(VERSION 3.16)
project(pcb_defect_qt_ui LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Widgets)

qt_standard_project_setup()

qt_add_executable(pcb_defect_qt_ui
    src/main.cpp
    src/main_window.cpp
    src/main_window.h
)

target_link_libraries(pcb_defect_qt_ui PRIVATE Qt6::Widgets)
