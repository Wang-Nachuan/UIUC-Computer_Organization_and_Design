package rv32i_types;
// Mux types are in their own packages to prevent identiier collisions
// e.g. pcmux::pc_plus4 and regfilemux::pc_plus4 are seperate identifiers
// for seperate enumerated types
import rsoprmux::*;

typedef logic [31:0] rv32i_word;
typedef logic [4:0] rv32i_reg;
typedef logic [3:0] rv32i_mem_wmask;


/*-------------------- OoO design --------------------*/ 

// Constant
parameter use_l2 = 1;

parameter SIZE_INSTQ = 8;       // Instruction queue size

/*----------------- Branch Predictor -----------------*/ 
// Max accuracy
// Accuracy for non-pipeline version: 0.889646 0.890148 0.854677
// parameter SIZE_GLOBAL_HIS = 8;  // BHT, gshare
// parameter SIZE_BH_TABLE = 7;    // PHT

// Accuracy: 0.842705 0.795163 0.832030
// parameter SIZE_GLOBAL_HIS = 8;  // BHT
// parameter SIZE_BH_TABLE = 7;    // PHT
// parameter SIZE_GSHARE_TABLE = 8; // gshare table

// Accuracy: 0.754605 0.806227 0.817875
parameter SIZE_GLOBAL_HIS = 7;  // BHT
parameter SIZE_BH_TABLE = 5;    // PHT
parameter SIZE_GSHARE_TABLE = 7; // gshare table

parameter SIZE_GLOBAL = SIZE_GLOBAL_HIS + 2;  // LEN global_PACKAGE
parameter DEPTH_BH_TABLE = 2 ** SIZE_GLOBAL_HIS;
parameter DEPTH_PH_TABLE = 2 ** SIZE_BH_TABLE;
parameter DEPTH_PH_TABLE_GSHARE = 2 ** SIZE_GSHARE_TABLE;
parameter LEN_INSTQ = 96 + SIZE_GLOBAL - 1;

/*----------------------- CPU -----------------------*/ 

parameter SIZE_RS_ALU = 4;      // Reservation station size (for ALU)
parameter SIZE_RS_BR = 4;       // Reservation station size (for branch)
parameter SIZE_RS_LSQ = 4;      // Reservation station size (for load/store)
parameter SIZE_ROB = 2*SIZE_RS_ALU + SIZE_RS_BR + SIZE_RS_LSQ;     // Reorder buffer size
// parameter SIZE_ROB = SIZE_RS_ALU + SIZE_RS_BR + SIZE_RS_LSQ;     // Reorder buffer size

parameter LEN_ID = $clog2(SIZE_ROB);    // Length of identifer
parameter LEN_OPC_ALU = 4;      // Length of opcode for ALU
parameter LEN_OPC_BR = 3;       // Length of opcode for branch
parameter LEN_OPC_LSQ = 3;      // Length of opcode for load/store

// Type of instruction
typedef enum bit [1:0] {
    itype_alu = 2'b00,          // ALU operation
    itype_br = 2'b01,           // Branch operation       
    itype_ls = 2'b10,           // Memory operation
    itype_mult = 2'b11          // Multiplication
} inst_type;

// CDB interfaces
typedef struct {
    logic valid;
    logic [31:0] data;
    logic [LEN_ID-1:0] id;
} cdb_data;

typedef struct {
    logic en;
    logic [SIZE_ROB-1:0] en_id;
} cdb_flush;

/*---------------- Instruction decode ----------------*/ 

typedef enum bit [6:0] {
    op_lui   = 7'b0110111, //load upper immediate (U type)
    op_auipc = 7'b0010111, //add upper immediate PC (U type)
    op_jal   = 7'b1101111, //jump and link (J type)
    op_jalr  = 7'b1100111, //jump and link register (I type)
    op_br    = 7'b1100011, //branch (B type)
    op_load  = 7'b0000011, //load (I type)
    op_store = 7'b0100011, //store (S type)
    op_imm   = 7'b0010011, //arith ops with register/immediate operands (I type)
    op_reg   = 7'b0110011, //arith ops with register operands (R type)
    op_csr   = 7'b1110011  //control and status register (I type)
} rv32i_opcode;

typedef enum bit [2:0] {
    beq  = 3'b000,
    bne  = 3'b001,
    blt  = 3'b100,
    bge  = 3'b101,
    bltu = 3'b110,
    bgeu = 3'b111
} branch_funct3_t;

typedef enum bit [2:0] {
    lb  = 3'b000,
    lh  = 3'b001,
    lw  = 3'b010,
    lbu = 3'b100,
    lhu = 3'b101
} load_funct3_t;

typedef enum bit [2:0] {
    sb = 3'b000,
    sh = 3'b001,
    sw = 3'b010
} store_funct3_t;

typedef enum bit [2:0] {
    add  = 3'b000, //check bit30 for sub if op_reg opcode
    sll  = 3'b001,
    slt  = 3'b010,
    sltu = 3'b011,
    axor = 3'b100,
    sr   = 3'b101, //check bit30 for logical/arithmetic
    aor  = 3'b110,
    aand = 3'b111
} arith_funct3_t;

// Opcode for ALU
typedef enum bit [3:0] {
    // Same as mp2
    alu_add = 4'd0,     // add/addi
    alu_sll = 4'd1,     // sll/slli (shift left - logical)
    alu_sra = 4'd2,     // sra/srai (shift right - arithmetic)
    alu_sub = 4'd3,     // sub
    alu_xor = 4'd4,     // xor/xori
    alu_srl = 4'd5,     // srl/srli (shift right - logical)
    alu_or  = 4'd6,     // or/ori
    alu_and = 4'd7,     // and/andi
    // New
    alu_slt = 4'd8,     // slt/slti (signed less-than)
    alu_sltu = 4'd9,    // sltu/sltiu (unsigned less-than)
    alu_lui = 4'd10,    // lui
    alu_auipc = 4'd11   // auipc
} alu_opc;

// Opcode for branch
typedef enum bit [2:0] {
    br_beq = 3'd0,
    br_bne = 3'd1,
    br_blt = 3'd2,
    br_bge = 3'd3,
    br_bltu = 3'd4,
    br_bgeu = 3'd5,
    br_jal = 3'd6,
    br_jalr = 3'd7
} br_opc;

// Opcode for load/store
typedef enum bit [2:0] {
    ls_lb = 3'd0,
    ls_lh = 3'd1,
    ls_lw = 3'd2,
    ls_lbu = 3'd3,
    ls_lhu = 3'd4,
    ls_sb = 3'd5,
    ls_sh = 3'd6,
    ls_sw = 3'd7
} ls_opc;

endpackage : rv32i_types

