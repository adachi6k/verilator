#!/usr/bin/env python3
# DESCRIPTION: Verilator: Verilog Test driver/expect definition
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2026 Verilator contributors
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import vltest_bootstrap

test.scenarios('simulator')

if not test.have_solver:
    test.skip("No constraint solver installed")

test.compile()

test.execute()

if test.vlt_all:
    # A derived size registration must also be rebound by a shallow base copy.
    cpp_files = test.glob_some(test.obj_dir + "/" + test.vm_prefix + "*.cpp")
    test.file_grep_any(
        cpp_files, r'(?s)BaseValues::[^:()]*_VupdateRandVars\([^)]*\) \{[^}]*?\.update_var\([^,]*__Vdata_size,')

test.passes()
