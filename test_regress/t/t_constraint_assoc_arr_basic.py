#!/usr/bin/env python3
# DESCRIPTION: Verilator: Verilog Test driver/expect definition
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of either the GNU Lesser General Public License Version 3
# or the Perl Artistic License Version 2.0.
# SPDX-FileCopyrightText: 2024 Wilson Snyder
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0

import vltest_bootstrap

test.scenarios('simulator')

if not test.have_solver:
    test.skip("No constraint solver installed")

test.compile()

test.execute()

# Exercise every key width and nested select with binary solver replies.
if test.vlt:
    test.execute(logfile=test.obj_dir + '/sim_binary.log',
                 run_env='VERILATOR_SOLVER="' + test.t_dir +
                 '/randomize_solver_tamper.py" TAMPER=binary_literals')

test.passes()
