# RISC-V-asm.jl

This is a small project done in collaboration with [@AndreiDuma](https://github.com/AndreiDuma).
It's a helper tool for his very cool [Master's thesis](https://github.com/AndreiDuma/SmithForth_RISC-V).

## Usage:
1. Open a `julia` REPL
2. `julia> include("src/instructions.jl")`
3. `julia> encode(parse("add s10, s10, a0")...)`

