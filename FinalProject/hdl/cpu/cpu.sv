module cpu
import rv32i_types::*;
(
    input clk,
    input rst,
    // Instruction memory
    input logic inst_mem_resp,
    input rv32i_word inst_mem_rdata,
    output logic inst_read,
    output rv32i_word inst_mem_address
    // Data memory
	// input logic data_mem_resp,
    // input rv32i_word data_mem_rdata, 
    // output logic data_read,
    // output logic data_write,
    // output logic [3:0] data_mbe,
    // output rv32i_word data_mem_address,
    // output rv32i_word data_mem_wdata
);

/*-------------------- Signal --------------------*/

// CDB
cdb_data cdb_data_in;
cdb_data cdb_data_out;
cdb_flush cdb_flush_in;
cdb_flush cdb_flush_out;
logic cdb_ctrl_resp_alu;

// Fetcher
logic [31:0] fetch_inst;    // Might be changed!
rv32i_word fetch_pc_next;
rv32i_word fetch_pc;
logic fetch_wen_inst;

// Instruction queue
logic iq_isfull;
rv32i_word iq_inst;
rv32i_word iq_pc;
rv32i_word iq_pc_next;
logic iq_rvalid;
logic iq_isempty;

// Issuer (not complete)
logic issue_req;
logic [1:0] issue_type;     // See type file
logic issue_isrd;
logic [4:0] issue_rd;
logic [4:0] issue_sr1;
logic [4:0] issue_sr2;
logic [31:0] issue_pc;
logic [31:0] issue_pcnext;
// Immediate value
logic [31:0] issue_i_imm;
logic [31:0] issue_s_imm;
logic [31:0] issue_b_imm;
logic [31:0] issue_u_imm;
logic [31:0] issue_j_imm;
// For RS1
logic issue_en_rs1;
alu_opc issue_opc_rs1;              // See type file
logic [2:0] issue_rs1_opr1_sel;     // See mux_type file
logic [2:0] issue_rs1_opr2_sel;     // See mux_type file
// For RS2
logic issue_en_rs2;
logic [2:0] issue_rs2_opr1_sel;
logic [2:0] issue_rs2_opr2_sel;
logic [2:0] issue_rs2_opr3_sel;
br_opc issue_opc_rs2;
// For RS3
logic issue_en_rs3;
logic [2:0] issue_rs3_opr1_sel;
logic [2:0] issue_rs3_opr2_sel;
logic [2:0] issue_rs3_opr3_sel;
ls_opc issue_opc_rs3;

// ROB
logic rob_isfull;
logic [LEN_ID-1:0] rob_id;
logic commit_rf_en;
logic [4:0] commit_rd;
logic [31:0] commit_data;
logic commit_ls_en;
logic [LEN_ID-1:0] commit_ls_id;
logic [31:0] flush_dep_rf_en;
logic [31:0][LEN_ID-1:0] flush_dep_rf;
logic [31:0] rob_pc;

// Register File
logic rf_sr1_rdy;
logic [LEN_ID-1:0] rf_sr1_id;
logic [31:0] rf_sr1_val;
logic rf_sr2_rdy;
logic [LEN_ID-1:0] rf_sr2_id;
logic [31:0] rf_sr2_val;

// RS1 (ALU)
logic rs1_isfull;
logic rs1_opr1_rdy;
logic [LEN_ID-1:0] rs1_opr1_id;
logic [31:0] rs1_opr1_val;
logic rs1_opr2_rdy;
logic [LEN_ID-1:0] rs1_opr2_id;
logic [31:0] rs1_opr2_val;
logic rs1_exe_req;
logic [LEN_ID-1:0] rs1_id;
logic [LEN_OPC_ALU-1:0] rs1_opc;
logic [31:0] rs1_opr1;
logic [31:0] rs1_opr2;

// ALU
logic alu_resp;
logic alu_finish;
cdb_data alu_data_out;

// RS2 (Branch)
logic rs2_isfull;

// Branch Unit
// input logic br_valid;
// input logic [LEN_ID-1:0] br_id;         // Id of br instruction
// input logic [31:0] br_addr;             // Correct address of branching

// RS3 (Load/Store)
logic rs3_isfull;

// Memory Unit

// Other signals

/*--------------------- Mux ----------------------*/

// Just for CP1
assign rs2_isfull = 1'b1;
assign rs3_isfull = 1'b1;

always_comb begin

    // CDB MUX
    cdb_ctrl_resp_alu = 1'b0;
    if (alu_data_out.valid) begin
        cdb_ctrl_resp_alu = 1'b1;
        cdb_data_in = alu_data_out;
    end

    // RS (ALU) OPR1 MUX
    rs1_opr1_rdy = 1'b1;
    rs1_opr1_id = {LEN_ID{1'b0}};
    rs1_opr1_val = 32'b0;
    unique case (issue_rs1_opr1_sel)
        rsoprmux::none: ;
        rsoprmux::sr: begin
            rs1_opr1_rdy = rf_sr1_rdy;
            rs1_opr1_id = rf_sr1_id;
            rs1_opr1_val = rf_sr1_val;
        end
        rsoprmux::pc:       rs1_opr1_val = issue_pc;
        rsoprmux::i_imm:    rs1_opr1_val = issue_i_imm;
        rsoprmux::u_imm:    rs1_opr1_val = issue_u_imm;
        rsoprmux::b_imm:    rs1_opr1_val = issue_b_imm;
        rsoprmux::s_imm:    rs1_opr1_val = issue_s_imm;
        rsoprmux::j_imm:    rs1_opr1_val = issue_j_imm;
    endcase

    // RS (ALU) OPR2 MUX
    rs1_opr2_rdy = 1'b1;
    rs1_opr2_id = {LEN_ID{1'b0}};
    rs1_opr2_val = 32'b0;
    unique case (issue_rs1_opr2_sel)
        rsoprmux::none: ;
        rsoprmux::sr: begin
            rs1_opr2_rdy = rf_sr2_rdy;
            rs1_opr2_id = rf_sr2_id;
            rs1_opr2_val = rf_sr2_val;
        end
        rsoprmux::pc:       rs1_opr2_val = issue_pc;
        rsoprmux::i_imm:    rs1_opr2_val = issue_i_imm;
        rsoprmux::u_imm:    rs1_opr2_val = issue_u_imm;
        rsoprmux::b_imm:    rs1_opr2_val = issue_b_imm;
        rsoprmux::s_imm:    rs1_opr2_val = issue_s_imm;
        rsoprmux::j_imm:    rs1_opr2_val = issue_j_imm;
    endcase
end

/*-------------------- Module --------------------*/

// Fetcher
fetcher #(
    .width(32)
) i_fetcher (
    .br_addr(32'b0),
    .flush(cdb_flush_out.en),
    .*
);

// Instruction queue
inst_queue #(
    .width(96),
    .depth(SIZE_INSTQ)
) i_inst_queue (
    .flush(cdb_flush_out.en),
    .*
);

// Issuer
issuer i_issuer (.*);

// CDB
cdb i_cdb (.*);

// ROB
rob #(
    .size(SIZE_ROB)
) i_rob (
    // Flush
    .br_valid(1'b0),
    .br_id({LEN_ID{1'b0}}),
    .br_addr(32'b0),
    .*
);

// Regfile
regfile #(
    .len_id(LEN_ID)
) i_regfile (
    .flush_rf_en(cdb_flush_out.en), 
    .*
);

// RS (ALU)
rs #(
    .size(SIZE_RS_ALU),
    .len_opc(LEN_OPC_ALU),
    .len_id(LEN_ID)
) i_rs1 (
    // Issue
    .issue_en(issue_en_rs1),
    .issue_opc(issue_opc_rs1),
    .rs_isfull(rs1_isfull),
    // ROB/Regfile
    .rs_id_in(rob_id),
    // sr1
    .rs_opr1_rdy(rs1_opr1_rdy),
    .rs_opr1_id(rs1_opr1_id),
    .rs_opr1_val(rs1_opr1_val),
    // sr2/imm/none
    .rs_opr2_rdy(rs1_opr2_rdy),
    .rs_opr2_id(rs1_opr2_id),
    .rs_opr2_val(rs1_opr2_val),
    // Execution unit
    .exe_resp(alu_resp),
    .exe_finish(alu_finish),
    .rs_exe_req(rs1_exe_req),
    .rs_id(rs1_id),
    .rs_opc(rs1_opc),
    .rs_opr1(rs1_opr1),
    .rs_opr2(rs1_opr2),
    // CDB & CLK & RST
    .*
);

// ALU
alu # (
    .len_id(LEN_ID),
    .len_opc(LEN_OPC_ALU)
) i_alu (
    // RS
    .rs_exe_req(rs1_exe_req),
    .rs_id(rs1_id),
    .rs_opc(rs1_opc),
    .rs_opr1(rs1_opr1),
    .rs_opr2(rs1_opr2),
    .alu_resp(alu_resp),
    .alu_finish(alu_finish),
    // CDB & CLK & RST
    .cdb_ctrl_resp(cdb_ctrl_resp_alu),
    .*
);

// RS (Branch Unit)

// Branch Unit

// RS (Memory Unit)

// Memory Unit


endmodule : cpu
