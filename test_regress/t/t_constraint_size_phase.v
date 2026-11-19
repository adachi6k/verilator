// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 Verilator contributors
// SPDX-License-Identifier: CC0-1.0

class SoftCycle;
  randc bit [1:0] value;
  rand bit [1:0] bridge, other;
  bit [1:0] limit, pin_other;
  bit impossible;
  constraint c {
    value == bridge;
    value < 3;
    soft bridge < limit;
    if (impossible) value == 3;
    other == pin_other;
  }
endclass

class SizedCycle;
  randc bit [1:0] value, elements[];
  int length;
  constraint c {
    value < 3;
    elements.size() == length;
    foreach (elements[i]) elements[i] < 3;
  }
endclass

class KeyWidths;
  typedef int row_t[byte];
  rand row_t array[], queue[$];
  constraint c {
    array.size() == 1;
    queue.size() == 1;
    foreach (array[i]) array[i][8'sd7] == 31;
    foreach (queue[i]) queue[i][8'sd7] == 37;
  }
endclass

class BaseValues;
  rand int data[];
  constraint c {foreach (data[i]) data[i] == 11;}
endclass

class DerivedSize extends BaseValues;
  constraint sz {data.size() == 3;}
endclass

class ForeachUnique;
  rand int outer[];
  rand bit bits[];
  int length;
  constraint c {
    outer.size() == length;
    foreach (outer[i]) {
      outer[i] == 0;
      unique {bits};
    }
  }
endclass

module t;
  initial begin
    begin : soft_cycle
      automatic SoftCycle s = new;
      bit [2:0] seen;
      s.limit = 1;
      if (s.randomize() != 1 || s.value != 0) $stop;
      s.limit = 3;
      s.pin_other = 1;
      repeat (3) begin
        if (s.randomize() != 1 || seen[s.value]) $stop;
        seen[s.value] = 1;
        s.impossible = 1;
        if (s.randomize() != 0) $stop;
        s.impossible = 0;
      end
      if (seen != 3'b111) $stop;
    end
    begin : sized_cycle
      automatic SizedCycle s = new;
      bit [2:0] seen, seen_elements[2];
      s.length = 2;
      repeat (3) begin
        if (s.randomize() != 1 || s.elements.size() != 2 || seen[s.value]) $stop;
        seen[s.value] = 1;
        foreach (s.elements[i]) begin
          if (seen_elements[i][s.elements[i]]) $stop;
          seen_elements[i][s.elements[i]] = 1;
        end
        s.length = -1;
        if (s.randomize() != 0) $stop;
        s.length = 2;
      end
      if (seen != 3'b111 || seen_elements[0] != seen || seen_elements[1] != seen) $stop;
    end
    begin : mixed_keys
      automatic KeyWidths k = new;
      KeyWidths::row_t row;
      row[7] = -1;
      k.array = new[1];
      k.array[0] = row;
      k.queue.push_back(row);
      if (k.randomize() != 1 || k.array[0][7] != 31 || k.queue[0][7] != 37) $stop;
    end
    begin : late_copy
      automatic BaseValues src = new;
      automatic DerivedSize derived = new;
      BaseValues duplicate;
      if (derived.randomize() != 1 || derived.data.size() != 3) $stop;
      src.data = new[2];
      duplicate = new src;
      src = null;
      if (duplicate.randomize() != 1 || duplicate.data.size() != 2) $stop;
      foreach (duplicate.data[i]) if (duplicate.data[i] != 11) $stop;
    end
    begin : foreach_unique
      automatic ForeachUnique u = new;
      u.outer = new[2];
      u.bits = new[3];
      u.length = 0;
      if (u.randomize() != 1 || u.outer.size() != 0) $stop;
      u.length = 1;
      if (u.randomize() != 0) $stop;
      u.bits = new[2];
      if (u.randomize() != 1 || u.outer.size() != 1 || u.bits[0] == u.bits[1]) $stop;
    end
    $write("*-* All Finished *-*\n");
    $finish;
  end
endmodule
