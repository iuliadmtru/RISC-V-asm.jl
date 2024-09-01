### Registers ###

global abi_registers = Dict{Symbol, Symbol}(
    # zero
    :zero => :x0,
    # ???
    :ra => :x1,
    :sp => :x2,
    :gp => :x3,
    :tp => :x4,
    :fp => :x8,
    # temporary
    :t0 => :x5,
    :t1 => :x6,
    :t2 => :x7,
    :t3 => :x28,
    :t4 => :x29,
    :t5 => :x30,
    :t6 => :x31,
    # saved
    :s0 => :x8,
    :s1 => :x9,
    :s2 => :x18,
    :s3 => :x19,
    :s4 => :x20,
    :s5 => :x21,
    :s6 => :x22,
    :s7 => :x23,
    :s8 => :x24,
    :s9 => :x25,
    :s10 => :x26,
    :s11 => :x27,
    # arguments
    :a0 => :x10,
    :a1 => :x11,
    :a2 => :x12,
    :a3 => :x13,
    :a4 => :x14,
    :a5 => :x15,
    :a6 => :x16,
    :a7 => :x17,
)
global machine_registers = Dict(Symbol("x$r") => r for r in 0:31)

# generate global variables with register names
all_registers = append!(collect(keys(abi_registers)), keys(machine_registers))
for reg in all_registers
    @eval global $reg = $(QuoteNode(reg))
end

function encode_register(r::Symbol)
    r′ = get(abi_registers, r, r)
    machine_registers[r′]
end

### Picking bits ###

function pick(bits::UInt32, from::Int, to::Int)
    window = bits >> to
    mask = UInt32(1 << (from - to + 1) - 1)

    return window & mask
end

pick_str(bits::UInt32, from::Int, to::Int) = bitstring(bits)[end-from:end-to]

function pick_hex(bits::UInt32, from::Int, to::Int)
    s = string(pick(bits, from, to); base=16) |> uppercase
    return lpad(s, (from - to + 1) ÷ 4, '0')
end


### I instructions ###

struct IInstr
    imm12::UInt32
    rs1::UInt32
    funct3::UInt32
    rd::UInt32
    opcode::UInt32
end

function IInstr(imm::UInt32, rs1::Symbol, funct3::UInt32, rd::Symbol, opcode::UInt32)
    return IInstr(
        pick(imm, 11, 0),  # imm[11:0]
        encode_register(rs1),
        funct3,
        encode_register(rd),
        opcode
    )
end

encode(instr::IInstr, ::Val{:bin}, args...) =
    instr.imm12 << 20  |
    instr.rs1 << 15    |
    instr.funct3 << 12 |
    instr.rd << 7      |
    instr.opcode

function encode(instr::IInstr, ::Val{:emacs}, ::Val{:env})
    imm12 = string("{{{imm(", pick_str(instr.imm12, 11, 0), ")}}}")
    rs1 = string("{{{rs1(", pick_str(instr.rs1, 4, 0), ")}}}")
    fn3 = string("{{{fn3(", pick_str(instr.funct3, 2, 0), ")}}}")
    rd = string("{{{rd(", pick_str(instr.rd, 4, 0), ")}}}")
    op = string("{{{op(", pick_str(instr.opcode, 6, 0), ")}}}")

    return "~000000000000~                      ~00000~          $fn3 ~00000~          $op"
    # return "$imm12         $rs1 $fn3 $rd  $op"
end

function encode(instr::IInstr, ::Val{:emacs}, ::Val{:shift})
    shamt = string("~000000~​{{{shamt(", pick_str(instr.imm12, 5, 0), ")}}}")
    rs1 = string("{{{rs1(", pick_str(instr.rs1, 4, 0), ")}}}")
    fn3 = string("{{{fn3(", pick_str(instr.funct3, 2, 0), ")}}}")
    rd = string("{{{rd(", pick_str(instr.rd, 4, 0), ")}}}")
    op = string("{{{op(", pick_str(instr.opcode, 6, 0), ")}}}")

    return "$shamt         $rs1 $fn3 $rd  $op"
end

function encode(instr::IInstr, ::Val{:emacs}, ::Val{:math})
    imm12 = string("{{{imm(0x", pick_hex(instr.imm12, 11, 0), ")}}}")
    rs1 = string("{{{rs1(", pick_str(instr.rs1, 4, 0), ")}}}")
    fn3 = string("{{{fn3(", pick_str(instr.funct3, 2, 0), ")}}}")
    rd = string("{{{rd(", pick_str(instr.rd, 4, 0), ")}}}")
    op = string("{{{op(", pick_str(instr.opcode, 6, 0), ")}}}")

    return "$imm12                    $rs1 $fn3 $rd  $op"
end

function encode(instr::IInstr, ::Val{:emacs}, ::Val{:load})
    off12 = string("{{{off(0x", pick_hex(instr.imm12, 11, 0), ")}}}")
    rs1 = string("{{{rs1(", pick_str(instr.rs1, 4, 0), ")}}}")
    fn3 = string("{{{fn3(", pick_str(instr.funct3, 2, 0), ")}}}")
    rd = string("{{{rd(", pick_str(instr.rd, 4, 0), ")}}}")
    op = string("{{{op(", pick_str(instr.opcode, 6, 0), ")}}}")

    return "$off12                    $rs1 $fn3 $rd  $op"
end

function encode(instr::IInstr, ::Val{:emacs}, ::Val{:jump})
    off12 = string("{{{off(0x", pick_hex(instr.imm12, 11, 0), ")}}}")
    rs1 = string("{{{rs1(", pick_str(instr.rs1, 4, 0), ")}}}")
    fn3 = string("{{{fn3(", pick_str(instr.funct3, 2, 0), ")}}}")
    rd = string("{{{rd(", pick_str(instr.rd, 4, 0), ")}}}")
    op = string("{{{op(", pick_str(instr.opcode, 6, 0), ")}}}")

    return "$off12                    $rs1 $fn3 $rd  $op"
end


### R instructions ###

struct RInstr
    funct7::UInt32
    rs2::UInt32
    rs1::UInt32
    funct3::UInt32
    rd::UInt32
    opcode::UInt32
end

function RInstr(funct7::UInt32, rs2::Symbol, rs1::Symbol, funct3::UInt32, rd::Symbol, opcode::UInt32)
    return RInstr(
        funct7,
        encode_register(rs2),
        encode_register(rs1),
        funct3,
        encode_register(rd),
        opcode
    )
end

encode(instr::RInstr, ::Val{:bin}) =
    instr.funct7 << 25 |
    instr.rs2 << 20    |
    instr.rs1 << 15    |
    instr.funct3 << 12 |
    instr.rd << 7      |
    instr.opcode

function encode(instr::RInstr, ::Val{:emacs})
    fn7 = string("{{{fn7(", pick_str(instr.funct7, 6, 0), ")}}}")
    rs2 = string("{{{rs2(", pick_str(instr.rs2, 4, 0), ")}}}")
    rs1 = string("{{{rs1(", pick_str(instr.rs1, 4, 0), ")}}}")
    fn3 = string("{{{fn3(", pick_str(instr.funct3, 2, 0), ")}}}")
    rd = string("{{{rd(", pick_str(instr.rd, 4, 0), ")}}}")
    op = string("{{{op(", pick_str(instr.opcode, 6, 0), ")}}}")

    return "$fn7 $rs2 $rs1 $fn3 $rd  $op"
end


### S instructions ###

struct SInstr
    imm7::UInt32
    rs2::UInt32
    rs1::UInt32
    funct3::UInt32
    imm5::UInt32
    opcode::UInt32
end

function SInstr(offset::Int32, rs2::Symbol, rs1::Symbol, funct3::UInt32, opcode::UInt32)
    imm = unsigned(offset)

    return SInstr(
        pick(imm, 11, 5),       # imm[11:5]
        encode_register(rs2),
        encode_register(rs1),
        funct3,
        pick(imm, 4, 0),        # imm[4:0]
        opcode
    )
end

encode(instr::SInstr, ::Val{:bin}) =
    instr.imm7 << 25   |
    instr.rs2 << 20    |
    instr.rs1 << 15    |
    instr.funct3 << 12 |
    instr.imm5 << 7    |
    instr.opcode

function encode(instr::SInstr, ::Val{:emacs})
    imm7 = string("{{{off(", pick_str(instr.imm7, 6, 0), ")}}}")
    rs2 = string("{{{rs2(", pick_str(instr.rs2, 4, 0), ")}}}")
    rs1 = string("{{{rs1(", pick_str(instr.rs1, 4, 0), ")}}}")
    fn3 = string("{{{fn3(", pick_str(instr.funct3, 2, 0), ")}}}")
    imm5 = string("{{{off(", pick_str(instr.imm5, 4, 0), ")}}}")
    op = string("{{{op(", pick_str(instr.opcode, 6, 0), ")}}}")

    return "$imm7 $rs2 $rs1 $fn3 $imm5 $op"
end


### B instructions ###

struct BInstr
    imm7::UInt32
    rs2::UInt32
    rs1::UInt32
    funct3::UInt32
    imm5::UInt32
    opcode::UInt32
end

function BInstr(offset::Int32, rs2::Symbol, rs1::Symbol, funct3::UInt32, opcode::UInt32)
    imm = unsigned(offset)

    return BInstr(
        pick(imm, 12, 12) << 6 |  pick(imm, 10, 5), # imm[12|10:5]
        encode_register(rs2),
        encode_register(rs1),
        funct3,
        pick(imm, 4, 1) << 1 | pick(imm, 11, 11), # imm[4:1|11]
        opcode
    )
end

encode(instr::BInstr, ::Val{:bin}) =
    instr.imm7 << 25   |
    instr.rs2 << 20    |
    instr.rs1 << 15    |
    instr.funct3 << 12 |
    instr.imm5 << 7    |
    instr.opcode

function encode(instr::BInstr, ::Val{:emacs})
    imm7 = string("{{{off(", pick_str(instr.imm7, 6, 0), ")}}}")
    rs2 = string("{{{rs2(", pick_str(instr.rs2, 4, 0), ")}}}")
    rs1 = string("{{{rs1(", pick_str(instr.rs1, 4, 0), ")}}}")
    fn3 = string("{{{fn3(", pick_str(instr.funct3, 2, 0), ")}}}")
    imm5 = string("{{{off(", pick_str(instr.imm5, 4, 0), ")}}}")
    op = string("{{{op(", pick_str(instr.opcode, 6, 0), ")}}}")

    return "$imm7 $rs2 $rs1 $fn3 $imm5 $op"
end


### U instructions ###

struct UInstr
    imm20::UInt32
    rd::UInt32
    opcode::UInt32
end

function UInstr(imm::UInt32, rd::Symbol, opcode::UInt32)
    return UInstr(
        imm,
        encode_register(rd),
        opcode
    )
end

encode(instr::UInstr, ::Val{:bin}) =
    instr.imm20 << 12 |
    instr.rd << 7     |
    instr.opcode

function encode(instr::UInstr, ::Val{:emacs})
    imm20 = string("{{{imm(0x", pick_hex(instr.imm20, 19, 0), ")}}}")
    rd = string("{{{rd(", pick_str(instr.rd, 4, 0), ")}}}")
    op = string("{{{op(", pick_str(instr.opcode, 6, 0), ")}}}")

    return "$imm20                                                  $rd  $op"
end


### J instructions ###

struct JInstr
    imm20::UInt32
    rd::UInt32
    opcode::UInt32
end

function JInstr(offset::Int32, rd::Symbol, opcode::UInt32)
    imm = unsigned(offset)

    return JInstr(
        pick(imm, 20, 20) << 19    | # imm[20]
            pick(imm, 10, 1) << 9  | # imm[10:1]
            pick(imm, 11, 11) << 8 | # imm[11]
            pick(imm, 19, 12),       # imm[19:12]
        encode_register(rd),
        opcode
    )
end

encode(instr::JInstr, ::Val{:bin}) =
    instr.imm20 << 12 |
    instr.rd << 7     |
    instr.opcode

function encode(instr::JInstr, ::Val{:emacs})
    imm20 = string("{{{off(", pick_str(instr.imm20, 19, 0), ")}}}")
    rd = string("{{{rd(", pick_str(instr.rd, 4, 0), ")}}}")
    op = string("{{{op(", pick_str(instr.opcode, 6, 0), ")}}}")

    return "$imm20                                     $rd  $op"
end
