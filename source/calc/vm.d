module calc.vm;
import calc.parser;
import std.format,
       std.traits,
       std.array,
       std.stdio,
       std.conv,
       std.math;

struct Stack(T) {
  T[] stack;

  @property T pop() {
    T t = stack[$ - 1];
    stack.length--;
    return t;
  }
  
  @property size_t length() {
    return stack.length;
  }

  @property void push(T value) {
    stack ~= value;
  }

  @property bool empty() {
    return stack.empty;
  }

  @property T front() {
    return pop;
  }

  @property void popFront() {
    pop;
  }

  @property void popAll() {
    foreach (_; this) {}
  }
}

abstract class StackValue {}
abstract class Number : StackValue {}
class Integer : Number {
  long value;
  this (long value) { this.value = value; }
  override string toString() { return "<Value-Integer> %d".format(this.value); }
}
class Floating : Number {
  double value;
  this (double value) { this.value = value; }
  override string toString() { return "<Value-Floating> %f".format(this.value); }
}
class Variable : StackValue {
  string value;
  this (string value) { this.value = value; }
  override string toString() { return "<Value-Variable> %s".format(this.value); }
}
class VAssign : StackValue { override string toString() { return "<Operator> VAssign"; } }
class BiPush : StackValue { override string toString() { return "<Operator> BiPush"; } }
class IAdd   : StackValue { override string toString() { return "<Operator> IAdd"; } }
class ISub   : StackValue { override string toString() { return "<Operator> ISub"; } }
class IMul   : StackValue { override string toString() { return "<Operator> IMul"; } }
class IDiv   : StackValue { override string toString() { return "<Operator> IDiv"; } }
class IMod   : StackValue { override string toString() { return "<Operator> IMod"; } }
class Print  : StackValue { override string toString() { return "<Operator> Print"; } }
abstract class Func : StackValue {
  abstract Number func(StackValue[] args);
  string name;
  size_t arg_count;
  this (string name, size_t arg_count) {
    this.name = name;
    this.arg_count = arg_count;
  }
  override string toString() { return "<Operator> Func[%s]".format(name); }
  bool checkArgs(StackValue[] args) {
    foreach (arg; args) {
      if (((cast(Number)arg) is null) && ((cast(Func)arg) is null)) {
        return false;
      }
    }
    return true;
  }
}

class Sqrt : Func {
  this () {
    super("sqrt", 1);
  }
  override Number func(StackValue[] args) {
    if (!checkArgs(args)) {
      throw new Exception("%s got invalid argument".format(name));
    }
    assert (args.length >= this.arg_count);
    auto e = args[0];
    if ((cast(Number)e) !is null) {
      double v;
      if ((cast(Integer)e) !is null) {
        v = (cast(Integer)e).value.to!double;
      } else {
        v = (cast(Floating)e).value;
      }
      return floating(std.math.sqrt(v));
    }

    if ((cast(Func)e) !is null) {
      Func f = cast(Func)e;
      if (args.length >= this.arg_count) {
        return this.func([f.func(args[this.arg_count..$])]);
      } else {
        return this.func([f.func([])]);
      }
    }

    throw new Error("ERROR");
  }
}

Sqrt sqrt() { return new Sqrt; }

class Square : Func {
  this () {
    super("square", 1);
  }
  override Number func(StackValue[] args) {
    if (!checkArgs(args)) {
      throw new Exception("%s got invalid argument".format(name));
    }
    assert (args.length >= this.arg_count);
    auto e = args[0];
    if ((cast(Number)e) !is null) {
      if ((cast(Integer)e) !is null) {
        long v = (cast(Integer)e).value;
        return integer(v * v);
      } else {
        double v = (cast(Floating)e).value;
        return floating(v * v);
      }
    }

    if ((cast(Func)e) !is null) {
      Func f = cast(Func)e;
      if (args.length >= this.arg_count) {
        return this.func([f.func(args[this.arg_count..$])]);
      } else {
        return this.func([f.func([])]);
      }
    }

    throw new Error("ERROR");
  }
}

Square square() { return new Square; }

class IPower : StackValue { override string toString() { return "<Operator> IPower"; } }

struct Frame {
  StackValue[] code;
  Stack!StackValue operandStack;
}

Frame execute(Frame frame) {
  StackValue[]     code         = frame.code;
  Stack!StackValue operandStack = frame.operandStack;
  StackValue       command      = code[0];
  size_t rpc = 1;

  if ((cast(BiPush)command) !is null) {
    assert (code.length > 1);
    operandStack.push(code[rpc++]);
  } else if ((cast(IAdd)command) !is null) {
    Number b = cast(Number)operandStack.pop,
           a = cast(Number)operandStack.pop;
    assert ((a !is null) && (b !is null));
    if ((cast(Floating)a) !is null || (cast(Floating)b) !is null) {
      Floating fa, fb;
      if ((cast(Floating)a) !is null) {
        fa = cast(Floating)a;
      } else {
        fa = floating((cast(Integer)a).value.to!double);
      }
      if ((cast(Floating)b) !is null) {
        fb = cast(Floating)b;
      } else {
        fb = floating((cast(Integer)b).value.to!double);
      }
      operandStack.push(floating(fa.value + fb.value));
    } else {
      operandStack.push(integer((cast(Integer)a).value + (cast(Integer)b).value));
    }
  } else if ((cast(ISub)command) !is null) {
    Number b = cast(Number)operandStack.pop,
           a = cast(Number)operandStack.pop;
    assert ((a !is null) && (b !is null));
    if ((cast(Floating)a) !is null || (cast(Floating)b) !is null) {
      Floating fa, fb;
      if ((cast(Floating)a) !is null) {
        fa = cast(Floating)a;
      } else {
        fa = floating((cast(Integer)a).value.to!double);
      }
      if ((cast(Floating)b) !is null) {
        fb = cast(Floating)b;
      } else {
        fb = floating((cast(Integer)b).value.to!double);
      }
      operandStack.push(floating(fa.value - fb.value));
    } else {
      operandStack.push(integer((cast(Integer)a).value - (cast(Integer)b).value));
    }
  } else if ((cast(IMul)command) !is null) {
    Number b = cast(Number)operandStack.pop,
           a = cast(Number)operandStack.pop;
    assert ((a !is null) && (b !is null));
    if ((cast(Floating)a) !is null || (cast(Floating)b) !is null) {
      Floating fa, fb;
      if ((cast(Floating)a) !is null) {
        fa = cast(Floating)a;
      } else {
        fa = floating((cast(Integer)a).value.to!double);
      }
      if ((cast(Floating)b) !is null) {
        fb = cast(Floating)b;
      } else {
        fb = floating((cast(Integer)b).value.to!double);
      }
      operandStack.push(floating(fa.value * fb.value));
    } else {
      operandStack.push(integer((cast(Integer)a).value * (cast(Integer)b).value));
    }
  } else if ((cast(IDiv)command) !is null) {
    Number b = cast(Number)operandStack.pop,
           a = cast(Number)operandStack.pop;
    assert ((a !is null) && (b !is null));
    if ((cast(Floating)a) !is null || (cast(Floating)b) !is null) {
      Floating fa, fb;
      if ((cast(Floating)a) !is null) {
        fa = cast(Floating)a;
      } else {
        fa = floating((cast(Integer)a).value.to!double);
      }
      if ((cast(Floating)b) !is null) {
        fb = cast(Floating)b;
      } else {
        fb = floating((cast(Integer)b).value.to!double);
      }
      operandStack.push(floating(fa.value / fb.value));
    } else {
      operandStack.push(integer((cast(Integer)a).value / (cast(Integer)b).value));
    }
  } else if ((cast(IMod)command) !is null) {
    Number b = cast(Number)operandStack.pop,
           a = cast(Number)operandStack.pop;
    assert ((a !is null) && (b !is null));
    if ((cast(Floating)a) !is null || (cast(Floating)b) !is null) {
      Floating fa, fb;
      if ((cast(Floating)a) !is null) {
        fa = cast(Floating)a;
      } else {
        fa = floating((cast(Integer)a).value.to!double);
      }
      if ((cast(Floating)b) !is null) {
        fb = cast(Floating)b;
      } else {
        fb = floating((cast(Integer)b).value.to!double);
      }
      operandStack.push(floating(fa.value % fb.value));
    } else {
      operandStack.push(integer((cast(Integer)a).value % (cast(Integer)b).value));
    }
  } else if ((cast(Print)command) !is null) {
    StackValue v = operandStack.pop;
    writeln(v);
    operandStack.push(v);
  } else if ((cast(Func)command) !is null) {
    StackValue[] args;
    Func f = cast(Func)command;
    size_t limit = f.arg_count;
    for (size_t i = 0; i < limit; i++) {
      StackValue v = operandStack.pop;
      if ((cast(Number)v) !is null) {
        args ~= v;
      } else if ((cast(Func)v) !is null) {
        Func vf = cast(Func)v;
        args ~= vf;
        limit += vf.arg_count;
      } else {
        throw new Error("Invalid argument - " ~ v.toString);
      }
    }
    operandStack.push(f.func(args));
  } else if ((cast(IPower)command) !is null) {
    Integer m = cast(Integer)operandStack.pop;
    Number  n = cast(Number)operandStack.pop;
    assert ((n !is null) && (m !is null));
    long p = m.value;

    if ((cast(Integer)n) !is null) {
      long v = (cast(Integer)n).value;
      operandStack.push(integer(v^^p));
    } else {
      double v = (cast(Floating)n).value;
      operandStack.push(floating(v^^p));
    }
  } else if ((cast(Variable)command) !is null) {
    Variable v = cast(Variable)command;
    operandStack.push(getVariable(v.value));
  } else if ((cast(VAssign)command) !is null) {
    Variable var = cast(Variable)code[rpc++];
    long     len = (cast(Integer)code[rpc++]).value;
    StackValue[] value = code[rpc..rpc+len];
    rpc += len;
    Frame f =Frame(value, Stack!StackValue());
    while (f.code.length != 0) {
      f = execute(f);
    }
    StackValue v = f.operandStack.pop;
    setVariable(var.value, v);
    operandStack.push(v);
  }

  return Frame(code[rpc..$], operandStack);
}

Integer integer(long value) { return new Integer(value); }
Floating floating(double value) { return new Floating(value); }
Variable variable(string value) { return new Variable(value); }
VAssign vassign()          { return new VAssign; }
BiPush bipush()            { return new BiPush; }
IAdd iadd()                { return new IAdd; }
ISub isub()                { return new ISub; }
IMul imul()                { return new IMul; }
IDiv idiv()                { return new IDiv; }
IMod imod()                { return new IMod; }
Print print()              { return new Print; }
IPower ipower()            { return new IPower; }

StackValue calculate(string src) {
	StackValue[] code = buildCode(Calc(src));
	Stack!StackValue operandStack;
	Frame frame = Frame(code, operandStack);
  while (frame.code.length != 0) {
    frame = execute(frame);
  }
	return frame.operandStack.stack[0];
}