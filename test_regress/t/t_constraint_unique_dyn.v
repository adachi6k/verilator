// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain
// SPDX-FileCopyrightText: 2026 BRDR LIFE
// SPDX-License-Identifier: CC0-1.0

// A 'unique' constraint holds over containers whose element count is only
// settled at randomize() time, and over an array it constrains on its own.

// verilog_format: off
`define stop $stop
`define checkh(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got='h%x exp='h%x\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0)
`define checkd(gotv,expv) do if ((gotv) !== (expv)) begin $write("%%Error: %s:%0d:  got=%0d exp=%0d\n", `__FILE__,`__LINE__, (gotv), (expv)); `stop; end while(0)
// verilog_format: on

class Sized;
  rand bit [3:0] q[$];
  rand bit [3:0] d[];

  constraint sz {
    q.size() == 3;
    d.size() == 5;
  }
  constraint uniq {
    unique {q};
    unique {d};
  }
endclass

class Tiny;
  rand bit [3:0] q[$];

  constraint sz {q.size() == 1;}
  constraint uniq {unique {q};}
endclass

class Sole;
  rand bit [1:0] arr[4];

  constraint uniq {unique {arr};}
endclass

class NumberedArrays;
  rand bit [4:0] a[11];
  rand bit [4:0] a1[1];
  constraint legal {
    unique {a};
    foreach (a[i]) a[i] == 5'(i + 1);
    a1[0] == 29;
  }
endclass

class StreamBase;
  typedef bit [4:0] values_t[];
  rand values_t values;
  rand bit [4:0] tag;
endclass

class CallbackStream extends StreamBase;
  int count = 10;
  constraint distinct_values {unique {values};}
  constraint nonzero {foreach (values[i]) values[i] != 0;}
  function void pre_randomize();
    values = new[count];
  endfunction
  function void check_values();
    `checkd(values.size(), count);
    foreach (values[i]) begin
      `checkd(values[i] != 0, 1);
      foreach (values[j]) if (j < i) `checkd(values[i] != values[j], 1);
    end
  endfunction
endclass

class CopiedValues;
  rand bit [4:0] values[];
  rand bit [4:0] other[1];
  bit [4:0] wanted = 9;
  constraint distinct_values {
    foreach (values[i]) values[i] != 0;
    unique {values, other};
  }
  constraint choose_other {other[0] == wanted;}
endclass

class SolverShrink;
  rand bit values[];
  constraint size_c {values.size() == 2;}
  constraint distinct_values {unique {values};}
  function void pre_randomize();
    values = new[3];
  endfunction
endclass

class IndependentSize;
  rand bit flags[2];
  rand bit [3:0] data[];
  constraint legal {
    unique {flags};
    data.size() == int'(flags[0]) + int'(flags[1]);
    soft flags[0] == flags[1];
    foreach (data[i]) data[i] == 0;
  }
endclass

module t;
  initial begin
    automatic Sized sized = new;
    automatic Tiny tiny = new;
    automatic Sole sole = new;
    int ok;

    for (int n = 0; n < 10; ++n) begin
      ok = sized.randomize();
      `checkd(ok, 1);
      `checkd(sized.q.size(), 3);
      `checkd(sized.d.size(), 5);
      foreach (sized.q[i]) foreach (sized.q[j]) if (i != j) `checkh(sized.q[i] == sized.q[j], 1'b0);
      foreach (sized.d[i]) foreach (sized.d[j]) if (i != j) `checkh(sized.d[i] == sized.d[j], 1'b0);

      // A single element is trivially unique
      ok = tiny.randomize();
      `checkd(ok, 1);
      `checkd(tiny.q.size(), 1);

      // Four distinct 2-bit values are a permutation of 0..3
      ok = sole.randomize();
      `checkd(ok, 1);
      foreach (sole.arr[i])
      foreach (sole.arr[j]) if (i != j) `checkh(sole.arr[i] == sole.arr[j], 1'b0);
    end

    begin
      automatic NumberedArrays d = new;
      repeat (3) begin
        ok = d.randomize();
        `checkd(ok, 1);
        foreach (d.a[i]) `checkd(d.a[i], 5'(i + 1));
        `checkd(d.a1[0], 29);
      end
    end

    begin
      automatic CallbackStream stream = new;
      automatic StreamBase handle = stream;
      ok = stream.randomize();
      `checkd(ok, 1);
      stream.check_values();
      for (int n = 4; n >= 0; --n) begin
        stream.count = n;
        ok = handle.randomize() with {tag == 7;};
        `checkd(ok, 1);
        `checkd(handle.tag, 7);
        stream.check_values();
      end
      stream.count = 10;
      stream.distinct_values.constraint_mode(0);
      ok = stream.randomize();
      `checkd(ok, 1);
      foreach (stream.values[i]) `checkd(stream.values[i] != 0, 1);
      stream.distinct_values.constraint_mode(1);
      ok = stream.randomize();
      `checkd(ok, 1);
      stream.check_values();
    end

    begin
      automatic CopiedValues original = new;
      CopiedValues copied;
      original.values = '{5, 8};
      copied = new original;
      copied.values.rand_mode(0);
      `checkd(original.values.rand_mode(), 1);
      ok = copied.randomize();
      `checkd(ok, 1);
      `checkd(copied.values[0], 5);
      `checkd(copied.values[1], 8);
      `checkd(copied.other[0], 9);
      `checkd(original.other[0], 0);
      copied.values[1] = 5;
      ok = copied.randomize();
      `checkd(ok, 0);
      `checkd(copied.values[1], 5);
      copied.values[1] = 8;
      copied.wanted = 5;
      ok = copied.randomize();
      `checkd(ok, 0);
      `checkd(copied.other[0], 9);
      copied.distinct_values.constraint_mode(0);
      ok = copied.randomize();
      `checkd(ok, 1);
      `checkd(copied.other[0], 5);
      `checkd(original.values[0], 5);
      `checkd(original.values[1], 8);
      original.values = '{0, 0};
      ok = original.randomize();
      `checkd(ok, 1);
      `checkd(original.values[0] != 0 && original.values[1] != 0, 1);
      `checkd(original.values[0] != original.values[1], 1);
      `checkd(copied.values[0], 5);
      `checkd(copied.values[1], 8);
    end

    begin
      automatic SolverShrink shrink = new;
      automatic IndependentSize independent = new;
      repeat (3) begin
        ok = shrink.randomize();
        `checkd(ok, 1);
        `checkd(shrink.values.size(), 2);
        `checkd(shrink.values[0] != shrink.values[1], 1);
        ok = independent.randomize();
        `checkd(ok, 1);
        `checkd(independent.data.size(), 1);
        `checkd(independent.flags[0] != independent.flags[1], 1);
      end
    end

    $write("*-* All Finished *-*\n");
    $finish;
  end
endmodule
