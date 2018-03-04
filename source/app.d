import calc.vm;
import std.string,
		   std.stdio;


void main(string[] args) {
	if (args.length > 1) {
		writeln(calculate(args[1..$].join));
	} else {
		while (true) {
			write("Formula : ");
			string src = readln.chomp;
			if (src == "exit") {
				break;
			}
			writeln(src, " = ", calculate(src));
		}
	}
}