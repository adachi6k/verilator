// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2015 Wilson Snyder
// SPDX-License-Identifier: CC0-1.0

module t (  /*AUTOARG*/
    // Outputs
    outwires,
    // Inputs
    inwires
);

  input [7:0] inwires[12:10];
  output wire [7:0] outwires[12:10];

  assign outwires[10] = inwires[11];
  assign outwires[11] = inwires[12];
  assign outwires[12] = inwires[13];  // must be an error here

  class Entry;
    bit mark;
  endclass

  class Picker;
    rand bit mark;
    Entry entries[-6:3];
    constraint match_mark {
      entries[7].mark == mark;
      entries[32'hffff_fffa].mark == mark;
    }
  endclass

endmodule
