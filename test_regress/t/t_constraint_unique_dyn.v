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
  constraint by_index {foreach (values[i]) int'(values[i]) == i;}
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

class KeyedValues;
  rand bit [7:0] entries[int];
  int key;
  constraint legal {
    unique {entries};
    entries[1] == 0;
  }
  function void pre_randomize();
    entries.delete();
    entries[key] = '1;
  endfunction
endclass

class CallbackQueue;
  rand bit [4:0] q[$];
  int count = 4;
  constraint legal {
    unique {q};
    foreach (q[i]) q[i] != 0;
  }
  function void pre_randomize();
    q.delete();
    repeat (count) q.push_back(0);
  endfunction
  function void check_values();
    `checkd(q.size(), count);
    foreach (q[i]) begin
      `checkd(q[i] != 0, 1);
      foreach (q[j]) if (j < i) `checkd(q[i] != q[j], 1);
    end
  endfunction
endclass

class StateValues;
  bit [3:0] values[];
  bit duplicate;
  constraint legal {unique {values};}
  function void pre_randomize();
    values = '{4, duplicate ? 4 : 7};
  endfunction
endclass

class ExplicitValues;
  bit [3:0] values[];
  constraint legal {unique {values};}
endclass

class StaticValues;
  static rand bit [3:0] values[];
  constraint legal {unique {values};}
endclass

class FrozenResize;
  rand bit [3:0] values[];
  int wanted;
  int count;
  constraint legal {
    values.size() == wanted;
    unique {values};
  }
  function void pre_randomize();
    values = new[count];
    foreach (values[i]) values[i] = 4'(i + 1);
  endfunction
endclass

class SizedCallbackStream extends CallbackStream;
  constraint length_c {values.size() == 3;}
endclass

class PlainCallbackStream extends CallbackStream;
endclass

class SizeChild;
  rand int data[];
endclass

class SizeParent;
  rand SizeChild first;
  rand SizeChild second;
  function new();
    first = new;
    second = new;
  endfunction
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

    begin
      automatic KeyedValues original = new;
      KeyedValues copy;
      original.key = 2;
      repeat (4) begin
        ok = original.randomize();
        `checkd(ok, 1);
        `checkd(original.entries.exists(2), 1);
        `checkd(original.entries.num(), 1);
      end
      copy = new original;
      original.key = 1;
      repeat (12) begin
        ok = original.randomize();
        `checkd(ok, 1);
        `checkd(original.entries.num(), 1);
        `checkd(original.entries[1], 0);
        `checkd(original.entries.exists(2), 0);
      end
      `checkd(copy.entries.exists(2), 1);
      `checkd(copy.entries.exists(1), 0);
    end

    begin
      automatic CallbackQueue q = new;
      CallbackQueue copy;
      for (int n = 5; n >= 0; --n) begin
        q.count = n;
        ok = q.randomize();
        `checkd(ok, 1);
        q.check_values();
      end
      q.q = '{1, 2, 3};
      copy = new q;
      copy.count = 4;
      ok = copy.randomize();
      `checkd(ok, 1);
      copy.check_values();
      `checkd(q.q.size(), 3);
      `checkd(q.q[0], 1);
    end

    begin
      automatic StateValues state_values = new;
      automatic ExplicitValues listed = new;
      state_values.duplicate = 1;
      ok = state_values.randomize();
      `checkd(ok, 0);
      `checkd(state_values.values[0], 4);
      `checkd(state_values.values[1], 4);
      state_values.duplicate = 0;
      ok = state_values.randomize();
      `checkd(ok, 1);
      `checkd(state_values.values[0], 4);
      `checkd(state_values.values[1], 7);
      listed.values = '{4, 4};
      ok = listed.randomize(values);
      `checkd(ok, 1);
      `checkd(listed.values[0] != listed.values[1], 1);
      listed.values = '{4, 4};
      ok = listed.randomize();
      `checkd(ok, 0);
      `checkd(listed.values[1], 4);
    end

    begin
      automatic StaticValues first = new;
      automatic StaticValues second = new;
      first.values = '{4, 4};
      second.values.rand_mode(0);
      ok = first.randomize();
      `checkd(ok, 0);
      `checkd(first.values[0], 4);
      `checkd(first.values[1], 4);
      first.values[1] = 7;
      ok = second.randomize();
      `checkd(ok, 1);
      `checkd(second.values[0], 4);
      `checkd(second.values[1], 7);
      first.values.rand_mode(1);
      second.values = '{0, 0};
      ok = second.randomize();
      `checkd(ok, 1);
      `checkd(first.values[0] != first.values[1], 1);
    end

    begin
      automatic FrozenResize d = new;
      d.count = 4;
      d.wanted = 4;
      ok = d.randomize();
      `checkd(ok, 1);
      d.values.rand_mode(0);
      d.count = 0;
      ok = d.randomize();
      `checkd(ok, 0);
      `checkd(d.values.size(), 0);
      d.count = 2;
      d.wanted = 2;
      ok = d.randomize();
      `checkd(ok, 1);
      `checkd(d.values[0], 1);
      `checkd(d.values[1], 2);
    end

    begin
      automatic CallbackStream base = new;
      automatic SizedCallbackStream sized_stream = new;
      automatic PlainCallbackStream plain = new;
      sized_stream.count = 3;
      ok = sized_stream.randomize();
      `checkd(ok, 1);
      sized_stream.check_values();
      base.count = 2;
      ok = base.randomize() with {values.size() == 2;};
      `checkd(ok, 1);
      base.check_values();
      plain.count = 5;
      ok = plain.randomize();
      `checkd(ok, 1);
      plain.check_values();
      base.count = 6;
      ok = base.randomize();
      `checkd(ok, 1);
      base.check_values();
      base.count = 6;
      ok = base.randomize() with {values.size() == 3;};
      `checkd(ok, 1);
      base.count = 3;
      base.check_values();
    end

    begin
      automatic SizeParent parent = new;
      ok = parent.randomize() with {
        first.data.size() == 2;
        second.data.size() == 4;
      };
      `checkd(ok, 1);
      `checkd(parent.first.data.size(), 2);
      `checkd(parent.second.data.size(), 4);
    end

    $write("*-* All Finished *-*\n");
    $finish;
  end
endmodule
