`define BAD_MUX_SEL $display("Illegal mux select")


module datapath
import rv32i_types::*;
(
    input clk,
    input rst,      // signal used by RVFI Monitor
    /* You will need to connect more signals to your datapath module*/

    // From Control
    input logic load_pc,
    input logic load_ir,
    input logic load_regfile,
    input logic load_mar,
    input logic load_mdr,
    input logic load_data_out,
    input pcmux::pcmux_sel_t pcmux_sel,
    input branch_funct3_t cmpop,
    input alumux::alumux1_sel_t alumux1_sel,
    input alumux::alumux2_sel_t alumux2_sel,
    input regfilemux::regfilemux_sel_t regfilemux_sel,
    input marmux::marmux_sel_t marmux_sel,
    input cmpmux::cmpmux_sel_t cmpmux_sel,
    input alu_ops aluop,

    // To Control
    output rv32i_opcode opcode,
    output logic [2:0] funct3,
    output logic [6:0] funct7,
    output logic br_en,
    output logic [4:0] rs1,
    output logic [4:0] rs2,
    output logic [1:0] mem_address_10,

    // From Memory
    input rv32i_word mem_rdata,

    // To Memory
    output rv32i_word mem_address,
    output rv32i_word mem_wdata
);

/******************* Signals Needed for RVFI Monitor *************************/
// IR
rv32i_word i_imm;
rv32i_word s_imm;
rv32i_word b_imm;
rv32i_word u_imm;
rv32i_word j_imm;
rv32i_reg rs1_i;
rv32i_reg rs2_i;
rv32i_reg rd;

assign rs1 = rs1_i;
assign rs2 = rs2_i;

// MDR
rv32i_word mdrreg_out;

// PC
rv32i_word pc_out;

// Regfile
rv32i_word rs1_out;
rv32i_word rs2_out;

// ALU
rv32i_word alu_out;

// CMP

// MAR Mux
rv32i_word marmux_out;

// RegFile Mux
rv32i_word regfilemux_out;

// PC Mux
rv32i_word pcmux_out;

// ALU Mux 1
rv32i_word alumux_1_out;

// ALU Mux 2
rv32i_word alumux_2_out;

// CMP Mux
rv32i_word cmpmux_out;

/*****************************************************************************/

// Memory read
rv32i_word marreg_out;
rv32i_word mdrreg_out_shift;    
assign mem_address = {marreg_out[31:2], 2'b00};
assign mdrreg_out_shift = mdrreg_out >> ('d8 * marreg_out[1:0]);    // Unsigned shift; that is where the alignment assumption is made

// Memory write
rv32i_word mem_wdata_shift;
assign mem_wdata_shift = rs2_out << ('d8 * alu_out[1:0]);   // That is (also) where the alignment assumption is made
assign mem_address_10 = marreg_out[1:0];

/***************************** Registers *************************************/
// Keep Instruction register named `IR` for RVFI Monitor

ir IR(
    .clk(clk),
    .rst(rst),
    .load(load_ir),
    .in(mdrreg_out),
    .funct3(funct3),
    .funct7(funct7),
    .opcode(opcode),
    .i_imm(i_imm),
    .s_imm(s_imm),
    .b_imm(b_imm),
    .u_imm(u_imm),
    .j_imm(j_imm),
    .rs1(rs1_i),
    .rs2(rs2_i),
    .rd(rd)
);

register MAR(
    .clk(clk),
    .rst(rst),
    .load(load_mar),
    .in(marmux_out),
    .out(marreg_out)
);

register MDR(
    .clk(clk),
    .rst(rst),
    .load(load_mdr),
    .in(mem_rdata),
    .out(mdrreg_out)
);

register MemDataOut(
    .clk(clk),
    .rst(rst),
    .load(load_data_out),
    .in(mem_wdata_shift),
    .out(mem_wdata)
);

pc_register PC(
    .clk(clk),
    .rst(rst),
    .load(load_pc),
    .in(pcmux_out),
    .out(pc_out)
);

regfile regfile(
    .clk(clk),
    .rst(rst),
    .load(load_regfile),
    .in(regfilemux_out),
    .src_a(rs1_i), 
    .src_b(rs2_i), 
    .dest(rd),
    .reg_a(rs1_out), 
    .reg_b(rs2_out)
);


/*****************************************************************************/

/******************************* ALU and CMP *********************************/
alu ALU(
    .aluop(aluop),
    .a(alumux_1_out),
    .b(alumux_2_out),
    .f(alu_out)
);

cmp CMP(
    .src_a(rs1_out),
    .src_b(cmpmux_out),
    .cmpop(cmpop),
    .br_en(br_en)
);
/*****************************************************************************/

/******************************** Muxes **************************************/
always_comb begin : MUXES
    // We provide one (incomplete) example of a mux instantiated using
    // a case statement.  Using enumerated types rather than bit vectors
    // provides compile time type safety.  Defensive programming is extremely
    // useful in SystemVerilog. 

    // PC Mux
    unique case (pcmux_sel)
        pcmux::pc_plus4:    pcmux_out = pc_out + 4;
        pcmux::alu_out:     pcmux_out = alu_out;
        pcmux::alu_mod2:    pcmux_out = {alu_out[31:1], 1'b0};
        default: `BAD_MUX_SEL;
    endcase

    // RegFile Mux
    unique case (regfilemux_sel)
        regfilemux::alu_out:    regfilemux_out = alu_out;
        regfilemux::br_en:      regfilemux_out = {31'b0, br_en};
        regfilemux::u_imm:      regfilemux_out = u_imm;
        regfilemux::lw:         regfilemux_out = mdrreg_out;
        regfilemux::pc_plus4:   regfilemux_out = pc_out + 4;
        regfilemux::lb:         regfilemux_out = {{24{mdrreg_out_shift[7]}}, mdrreg_out_shift[7:0]};
        regfilemux::lbu:        regfilemux_out = {24'b0, mdrreg_out_shift[7:0]};
        regfilemux::lh:         regfilemux_out = {{16{mdrreg_out_shift[15]}}, mdrreg_out_shift[15:0]};
        regfilemux::lhu:        regfilemux_out = {16'b0, mdrreg_out_shift[15:0]};
        default: `BAD_MUX_SEL;
    endcase

    // MAR Mux
    unique case (marmux_sel)
        marmux::pc_out:     marmux_out = pc_out;
        marmux::alu_out:    marmux_out = alu_out;
        default: `BAD_MUX_SEL;
    endcase

    // ALU Mux 1
    unique case (alumux1_sel)
        alumux::rs1_out:    alumux_1_out = rs1_out;
        alumux::pc_out:     alumux_1_out = pc_out;
        default: `BAD_MUX_SEL;
    endcase

    // ALU Mux 2
    unique case (alumux2_sel)
        alumux::i_imm:      alumux_2_out = i_imm;
        alumux::u_imm:      alumux_2_out = u_imm;
        alumux::b_imm:      alumux_2_out = b_imm;
        alumux::s_imm:      alumux_2_out = s_imm;
        alumux::j_imm:      alumux_2_out = j_imm;
        alumux::rs2_out:    alumux_2_out = rs2_out;
        default: `BAD_MUX_SEL;
    endcase

    // CMP Mux
    unique case (cmpmux_sel)
        cmpmux::rs2_out:    cmpmux_out = rs2_out;
        cmpmux::i_imm:      cmpmux_out = i_imm;
        default: `BAD_MUX_SEL;
    endcase
end
/*****************************************************************************/
endmodule : datapath
