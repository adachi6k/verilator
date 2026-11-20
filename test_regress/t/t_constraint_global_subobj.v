// DESCRIPTION: Verilator: Verilog Test module
//
// This file ONLY is placed under the Creative Commons Public Domain.
// SPDX-FileCopyrightText: 2026 PlanV GmbH
// SPDX-License-Identifier: CC0-1.0

// Scenario 1 (issue #7833 literal): owner SA1 declares a global constraint on a
// sub-object's type but is NEVER randomized; a standalone randomize() of the
// holder must still randomize the nested fields.
class C1;
  rand int x;
  rand int y;
endclass

class B1;
  rand C1 c;
  function new();
    c = new();
  endfunction
endclass

class SA1;
  rand B1 b;
  constraint c_foo {b.c.x == 123;}
endclass

// Scenario 2 (combined): the SAME design randomizes both the constraint owner
// and a standalone holder of the constrained type.
class C2;
  rand int x;
  rand int y;
endclass

class B2;
  rand C2 c;
  function new();
    c = new();
  endfunction
endclass

class SA2;
  rand B2 b;
  constraint c_foo {b.c.x == 123;}
  function new();
    b = new();
  endfunction
endclass

// Scenario 3 (multiple same-type sub-objects): two sub-objects of one type are
// each pinned by a global constraint while that type is also randomized
// standalone; the two share one underlying rand variable.
class C3;
  rand int x;
endclass

class M3;
  rand C3 c1;
  rand C3 c2;
  constraint c {
    c1.x == 11;
    c2.x == 22;
  }
  function new();
    c1 = new();
    c2 = new();
  endfunction
endclass

// Scenario 4 (global constraint owner with its own size-constrained array): the
// owner basic-randomizes first, the solver overrides last, and the size-only
// resize fallback still resizes from the solver-determined size.
class C4;
  rand int x;
endclass

class A4;
  rand C4 c;
  rand int arr[];
  constraint c_sub {c.x == 5;}
  constraint c_size {arr.size() == 4;}
  function new();
    c = new();
  endfunction
endclass

// Scenario 5: state fields supply the size, including through nested rand handles.
class C5;
  rand int count;
  int length;
endclass

class B5;
  rand C5 cfg = new;
  rand C5 cfgs[1];
  rand C5 dynamic_cfgs[];
  rand C5 by_key[int][1];
  rand C5 queued[$];

  function new();
    cfgs[0] = cfg;
    dynamic_cfgs = new[1];
    dynamic_cfgs[0] = cfg;
    by_key[7][0] = cfg;
    queued.push_back(cfg);
  endfunction
endclass

class A5;
  typedef enum bit [1:0] {
    A = 1,
    B = 2
  } value_t;
  C5 cfg = new;
  rand B5 b = new;
  rand value_t arr[];
  constraint c_size {
    arr.size() == cfg.count;
    arr.size() == b.cfg.length;
    arr.size() == b.cfgs[0].length;
    arr.size() == b.dynamic_cfgs[0].length;
    arr.size() == b.by_key[7][0].length;
    arr.size() == b.queued[$].length;
  }

  function void check_size(int n);
    cfg.count = n;
    b.cfg.length = n;
    if (this.randomize() != 1) $stop;
    if (cfg.count != n || b.cfg.length != n || arr.size() != n) $stop;
    foreach (arr[i]) begin
      if (!(arr[i] inside {A, B})) $fatal(1, "arr[%0d]=%0d, size=%0d", i, arr[i], n);
    end
  endfunction
endclass

// Scenario 6: a random child field used as an index is itself constrained.
class Index6;
  rand bit [2:0] idx;
endclass

class A6;
  rand Index6 child = new;
  rand bit flags[8];
  int chosen;
  constraint c {
    foreach (flags[i]) flags[i] == (i == chosen);
    flags[child.idx] == 1;
  }
endclass

module t_constraint_global_subobj;
  B1 b1;
  SA2 a2;
  B2 b2;
  M3 m3;
  C3 s3;
  A4 a4;
  A5 a5;
  A6 a6;
  int prevx, prevy, p3;
  bit varyx, varyy, vary3;

  initial begin
    // Scenario 1: SA1 never randomized; standalone B1 must vary both fields.
    b1 = new();
    varyx = 0;
    varyy = 0;
    if (b1.randomize() != 1) $stop;
    prevx = b1.c.x;
    prevy = b1.c.y;
    for (int i = 0; i < 20; i++) begin
      if (b1.randomize() != 1) $stop;
      if (b1.c.x != prevx) varyx = 1;
      if (b1.c.y != prevy) varyy = 1;
      prevx = b1.c.x;
      prevy = b1.c.y;
    end
    if (!varyx || !varyy) begin
      $display("ERROR: standalone holder fields stuck (varyx=%0d varyy=%0d)", varyx, varyy);
      $stop;
    end

    // Scenario 2: randomize the owner (constraint applies) and a standalone
    // holder (fields random) in the same design.
    a2 = new();
    if (a2.randomize() != 1) $stop;
    if (a2.b.c.x != 123) begin
      $display("ERROR: owner constraint not applied, a2.b.c.x=%0d", a2.b.c.x);
      $stop;
    end
    b2 = new();
    varyx = 0;
    if (b2.randomize() != 1) $stop;
    prevx = b2.c.x;
    for (int i = 0; i < 20; i++) begin
      if (b2.randomize() != 1) $stop;
      if (b2.c.x != prevx) varyx = 1;
      prevx = b2.c.x;
    end
    if (!varyx) begin
      $display("ERROR: standalone holder x stuck while owner also randomized");
      $stop;
    end

    // Scenario 3: two same-type sub-objects each pinned, plus standalone vary.
    m3 = new();
    if (m3.randomize() != 1) $stop;
    if (m3.c1.x != 11) begin
      $display("ERROR: m3.c1.x should be 11, got %0d", m3.c1.x);
      $stop;
    end
    if (m3.c2.x != 22) begin
      $display("ERROR: m3.c2.x should be 22, got %0d", m3.c2.x);
      $stop;
    end
    s3 = new();
    vary3 = 0;
    if (s3.randomize() != 1) $stop;
    p3 = s3.x;
    for (int i = 0; i < 20; i++) begin
      if (s3.randomize() != 1) $stop;
      if (s3.x != p3) vary3 = 1;
      p3 = s3.x;
    end
    if (!vary3) begin
      $display("ERROR: standalone same-type x stuck");
      $stop;
    end

    // Scenario 4: owner with a global constraint AND its own size constraint.
    a4 = new();
    if (a4.randomize() != 1) $stop;
    if (a4.c.x != 5) begin
      $display("ERROR: a4.c.x should be 5, got %0d", a4.c.x);
      $stop;
    end
    if (a4.arr.size() != 4) begin
      $display("ERROR: a4.arr.size() should be 4, got %0d", a4.arr.size());
      $stop;
    end

    a5 = new;
    a5.check_size(4);
    a5.check_size(7);
    a5.check_size(2);
    a5.check_size(0);
    a5.check_size(3);

    a6 = new;
    for (int i = 0; i < 8; i++) begin
      a6.chosen = i;
      if (a6.randomize() != 1) $stop;
      if (int'(a6.child.idx) != i) $fatal(1, "child.idx=%0d, expected %0d", a6.child.idx, i);
    end

    $write("*-* All Finished *-*\n");
    $finish;
  end
endmodule
