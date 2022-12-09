module cpu
import rv32i_types::*;
(
    input clk,
    input rst,
    // Instruction memory
    input logic inst_mem_resp,
    input logic [63:0] inst_mem_rdata,
    output logic inst_read,
    output rv32i_word inst_mem_address,
    // Data memory
	input logic data_mem_resp,
    input rv32i_word data_mem_rdata, 
    output logic data_read,
    output logic data_write,
    output logic [3:0] data_mbe,
    output rv32i_word data_mem_address,
    output rv32i_word data_mem_wdata
);

/*-------------------- Signal --------------------*/

// CDB
cdb_data cdb_data_in;
cdb_data cdb_data_out;
cdb_flush cdb_flush_in;
cdb_flush cdb_flush_out;
logic cdb_ctrl_resp_alu1;
logic cdb_ctrl_resp_alu2;
logic cdb_ctrl_resp_br;
logic cdb_ctrl_resp_ls;

// Fetcher
logic [31:0] fetch_inst;    // Might be changed!
rv32i_word fetch_pc_next;
rv32i_word fetch_pc;
logic fetch_wen_inst;
logic [SIZE_GLOBAL-1:0] fetch_br_history;
logic br_op;

// Instruction queue
logic iq_isfull;
rv32i_word iq_inst;
rv32i_word iq_pc;
rv32i_word iq_pc_next;
logic iq_rvalid;
logic iq_isempty;
logic [SIZE_GLOBAL-1:0] iq_br_history;
logic br_en; //added by zzy

// Issuer (not complete)
logic issue_req;
logic [1:0] issue_type;     // See type file
logic issue_isrd;
logic [4:0] issue_rd;
logic [4:0] issue_sr1;
logic [4:0] issue_sr2;
logic [31:0] issue_pc;
logic [31:0] issue_pcnext;
logic [SIZE_GLOBAL-1:0] issue_br_history;

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
br_opc issue_opc_rs2;
logic [2:0] issue_rs2_opr1_sel;
logic [2:0] issue_rs2_opr2_sel;
logic [2:0] issue_rs2_opr3_sel;
// For RS3
logic issue_en_lsq;
ls_opc issue_opc_lsq;
logic [2:0] issue_lsq_opr1_sel;
logic [2:0] issue_lsq_opr2_sel;
logic [2:0] issue_lsq_opr3_sel;

// ROB
logic rob_isfull;
logic [LEN_ID-1:0] rob_id;
logic rob_sr1_rdy;
logic [31:0] rob_sr1_val;
logic rob_sr2_rdy;
logic [31:0] rob_sr2_val;
logic commit_rf_en;
logic [4:0] commit_rd;
logic [31:0] commit_data;
logic [LEN_ID-1:0] commit_id;
logic commit_lsq_en;
logic [LEN_ID-1:0] commit_lsq_id;
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

// RS11
logic issue_en_rs11;
logic rs11_isfull;
logic rs11_exe_req;
logic [LEN_ID-1:0] rs11_id;
logic [LEN_OPC_ALU-1:0] rs11_opc;
logic [31:0] rs11_opr1;
logic [31:0] rs11_opr2;

// RS12
logic issue_en_rs12;
logic rs12_isfull;
logic rs12_exe_req;
logic [LEN_ID-1:0] rs12_id;
logic [LEN_OPC_ALU-1:0] rs12_opc;
logic [31:0] rs12_opr1;
logic [31:0] rs12_opr2;

// ALU 1
logic alu1_resp;
logic alu1_finish;
cdb_data alu1_data_out;

// ALU 2
logic alu2_resp;
logic alu2_finish;
cdb_data alu2_data_out;

// RS2 (Branch)
logic rs2_isfull;
logic rs2_opr1_rdy;
logic [LEN_ID-1:0] rs2_opr1_id;
logic [31:0] rs2_opr1_val;
logic rs2_opr2_rdy;
logic [LEN_ID-1:0] rs2_opr2_id;
logic [31:0] rs2_opr2_val;
logic [31:0] rs2_imm_val;
logic [31:0] rs2_pc_val;
logic rs2_exe_req;
logic [LEN_ID-1:0] rs2_id;
logic [LEN_OPC_BR-1:0] rs2_opc;
logic [31:0] rs2_opr1;
logic [31:0] rs2_opr2;
logic [31:0] rs2_imm;
logic [31:0] rs2_pc;
logic [SIZE_GLOBAL-1:0] rs2_br_history;

// Branch Unit
logic br_resp;
logic br_finish;
cdb_data br_data_out;
logic br_valid;
logic [LEN_ID-1:0] br_id;
logic [31:0] br_addr;
logic [31:0] br_pc;
logic [SIZE_GLOBAL-1:0] br_history_old;

// Load/Store Unit
logic lsq_isfull;
logic lsq_opr1_rdy;
logic [LEN_ID-1:0] lsq_opr1_id;
logic [31:0] lsq_opr1_val;
logic lsq_opr2_rdy;
logic [LEN_ID-1:0] lsq_opr2_id;
logic [31:0] lsq_opr2_val;
logic [31:0] lsq_imm_val;
// logic cdb_ctrl_resp_lsq;
cdb_data lsq_data_out;

/*------------------- Two RS1 --------------------*/

logic issue_rs1_ptr, issue_rs1_ptr_n;
always_ff @(posedge clk) begin
    if (rst)
        issue_rs1_ptr <= 1'b0;
    else begin
        issue_rs1_ptr <= issue_rs1_ptr_n;
    end
end

always_comb begin

    rs1_isfull = rs11_isfull & rs12_isfull;

    // Choose RS to issue
    issue_en_rs11 = 1'b0;
    issue_en_rs12 = 1'b0;
    issue_rs1_ptr_n = issue_rs1_ptr;
    if (issue_req & issue_en_rs1) begin
        if (issue_rs1_ptr == 1'b0) begin
            if (~rs11_isfull)
                issue_en_rs11 = 1'b1;
            else
                issue_en_rs12 = 1'b1;
        end
        else begin
            if (~rs12_isfull)
                issue_en_rs12 = 1'b1;
            else
                issue_en_rs11 = 1'b1;
        end
        issue_rs1_ptr_n = ~issue_rs1_ptr;
    end
end

/*--------------------- Mux ----------------------*/

always_comb begin

    // CDB MUX
    // cdb_ctrl_resp_lsq = 1'b0;
    cdb_ctrl_resp_alu1 = 1'b0;
    cdb_ctrl_resp_alu2 = 1'b0;
    cdb_ctrl_resp_br = 1'b0;
    if (lsq_data_out.valid) begin
        cdb_data_in = lsq_data_out;
    end
    else if (alu1_data_out.valid) begin
        cdb_ctrl_resp_alu1 = 1'b1;
        cdb_data_in = alu1_data_out;
    end
    else if (alu2_data_out.valid) begin
        cdb_ctrl_resp_alu2 = 1'b1;
        cdb_data_in = alu2_data_out;
    end
    else begin
        cdb_ctrl_resp_br = 1'b1;
        cdb_data_in = br_data_out;
    end

    // RS1 (ALU) OPR1 MUX (reg/pc)
    rs1_opr1_rdy = 1'b1;
    rs1_opr1_id = {LEN_ID{1'b0}};
    rs1_opr1_val = 32'b0;
    case (issue_rs1_opr1_sel)
        rsoprmux::sr: begin
            if (rf_sr1_rdy) begin
                rs1_opr1_rdy = 1'b1;
                rs1_opr1_id = rf_sr1_id;
                rs1_opr1_val = rf_sr1_val; 
            end
            else begin
                rs1_opr1_rdy = rob_sr1_rdy;
                rs1_opr1_id = rf_sr1_id;
                rs1_opr1_val = rob_sr1_val; 
            end
        end
        rsoprmux::pc: rs1_opr1_val = issue_pc;
    endcase

    // RS1 (ALU) OPR2 MUX (reg/pc/imm)
    rs1_opr2_rdy = 1'b1;
    rs1_opr2_id = {LEN_ID{1'b0}};
    rs1_opr2_val = 32'b0;
    case (issue_rs1_opr2_sel)
        rsoprmux::sr: begin
            if (rf_sr2_rdy) begin
                rs1_opr2_rdy = 1'b1;
                rs1_opr2_id = rf_sr2_id;
                rs1_opr2_val = rf_sr2_val;
            end
            else begin
                rs1_opr2_rdy = rob_sr2_rdy;
                rs1_opr2_id = rf_sr2_id;
                rs1_opr2_val = rob_sr2_val;
            end
        end
        rsoprmux::pc: rs1_opr2_val = issue_pc;
        rsoprmux::i_imm: rs1_opr2_val = issue_i_imm;
        rsoprmux::u_imm: rs1_opr2_val = issue_u_imm;
        rsoprmux::b_imm: rs1_opr2_val = issue_b_imm;
        rsoprmux::s_imm: rs1_opr2_val = issue_s_imm;
        rsoprmux::j_imm: rs1_opr2_val = issue_j_imm;
    endcase

    // RS2 (BR) OPR1 MUX (reg/pc)
    rs2_opr1_rdy = 1'b1;
    rs2_opr1_id = {LEN_ID{1'b0}};
    rs2_opr1_val = 32'b0;
    case (issue_rs2_opr1_sel)
        rsoprmux::sr: begin
            if (rf_sr1_rdy) begin
                rs2_opr1_rdy = 1'b1;
                rs2_opr1_id = rf_sr1_id;
                rs2_opr1_val = rf_sr1_val; 
            end
            else begin
                rs2_opr1_rdy = rob_sr1_rdy;
                rs2_opr1_id = rf_sr1_id;
                rs2_opr1_val = rob_sr1_val; 
            end
        end
        rsoprmux::pc: rs2_opr1_val = issue_pc;
    endcase

    // RS2 (BR) OPR2 MUX (reg)
    rs2_opr2_rdy = 1'b1;
    rs2_opr2_id = {LEN_ID{1'b0}};
    rs2_opr2_val = 32'b0;
    case (issue_rs2_opr2_sel)
        rsoprmux::sr: begin
            if (rf_sr2_rdy) begin
                rs2_opr2_rdy = 1'b1;
                rs2_opr2_id = rf_sr2_id;
                rs2_opr2_val = rf_sr2_val;
            end
            else begin
                rs2_opr2_rdy = rob_sr2_rdy;
                rs2_opr2_id = rf_sr2_id;
                rs2_opr2_val = rob_sr2_val;
            end
        end
    endcase

    // RS2 (BR) IMM MUX (imm)
    rs2_imm_val = 32'b0;
    case (issue_rs2_opr3_sel)
        rsoprmux::i_imm: rs2_imm_val = issue_i_imm;
        rsoprmux::b_imm: rs2_imm_val = issue_b_imm;
        rsoprmux::j_imm: rs2_imm_val = issue_j_imm;
    endcase

    rs2_pc_val = issue_pc;

    // LSQ OPR1 MUX (base reg)
    lsq_opr1_rdy = 1'b1;
    lsq_opr1_id = {LEN_ID{1'b0}};
    lsq_opr1_val = 32'b0;
    case (issue_lsq_opr1_sel)
        rsoprmux::sr: begin
            if (rf_sr1_rdy) begin
                lsq_opr1_rdy = 1'b1;
                lsq_opr1_id = rf_sr1_id;
                lsq_opr1_val = rf_sr1_val;
            end
            else begin
                lsq_opr1_rdy = rob_sr1_rdy;
                lsq_opr1_id = rf_sr1_id;
                lsq_opr1_val = rob_sr1_val;
            end
        end
    endcase

    // LSQ OPR2 MUX (src)
    lsq_opr2_rdy = 1'b1;
    lsq_opr2_id = {LEN_ID{1'b0}};
    lsq_opr2_val = 32'b0;
    case (issue_lsq_opr2_sel)
        rsoprmux::sr: begin
            if (rf_sr2_rdy) begin
                lsq_opr2_rdy = 1'b1;
                lsq_opr2_id = rf_sr2_id;
                lsq_opr2_val = rf_sr2_val;
            end
            else begin
                lsq_opr2_rdy = rob_sr2_rdy;
                lsq_opr2_id = rf_sr2_id;
                lsq_opr2_val = rob_sr2_val;
            end
        end
    endcase

    // LSQ IMM MUX (imm)
    lsq_imm_val = 32'b0;
    case (issue_lsq_opr3_sel)
        rsoprmux::i_imm: lsq_imm_val = issue_i_imm;
        rsoprmux::s_imm: lsq_imm_val = issue_s_imm;
    endcase
end

/*-------------------- Module --------------------*/

// Fetcher
fetcher #(
    .width(32)
) i_fetcher (.flush(cdb_flush_out.en), .*);

// Instruction queue
inst_queue #(
    .width(96),
    .depth(SIZE_INSTQ)
) i_inst_queue (.flush(cdb_flush_out.en), .*);

// Issuer
issuer i_issuer (.flush(cdb_flush_out.en), .*);

// CDB
cdb i_cdb (.*);

// ROB
rob #(.size(SIZE_ROB)) i_rob (.*);

// Regfile
regfile #(.len_id(LEN_ID)) i_regfile (.flush_rf_en(cdb_flush_out.en), .*);

/*------------------------------*/

// RS1 (ALU1)
rs1 #(
    .size(SIZE_RS_ALU),
    .len_opc(LEN_OPC_ALU),
    .len_id(LEN_ID)
) i_rs11 (
    .issue_en_rs1(issue_en_rs11),
    .rs1_isfull(rs11_isfull),
    .alu_resp(alu1_resp),
    .alu_finish(alu1_finish),
    .rs1_exe_req(rs11_exe_req),
    .rs1_id(rs11_id),
    .rs1_opc(rs11_opc),
    .rs1_opr1(rs11_opr1),
    .rs1_opr2(rs11_opr2),
    .*
);

// RS1 (ALU2)
rs1 #(
    .size(SIZE_RS_ALU),
    .len_opc(LEN_OPC_ALU),
    .len_id(LEN_ID)
) i_rs12 (
    .issue_en_rs1(issue_en_rs12),
    .rs1_isfull(rs12_isfull),
    .alu_resp(alu2_resp),
    .alu_finish(alu2_finish),
    .rs1_exe_req(rs12_exe_req),
    .rs1_id(rs12_id),
    .rs1_opc(rs12_opc),
    .rs1_opr1(rs12_opr1),
    .rs1_opr2(rs12_opr2),
    .*
);

// ALU 1
alu #(
    .len_id(LEN_ID),
    .len_opc(LEN_OPC_ALU)
) i_alu1 (
    .rs1_exe_req(rs11_exe_req),
    .rs1_id(rs11_id),
    .rs1_opc(rs11_opc),
    .rs1_opr1(rs11_opr1),
    .rs1_opr2(rs11_opr2),
    .alu_resp(alu1_resp),
    .alu_finish(alu1_finish),
    .cdb_ctrl_resp_alu(cdb_ctrl_resp_alu1),
    .alu_data_out(alu1_data_out),
    .*
);

// ALU 2
alu #(
    .len_id(LEN_ID),
    .len_opc(LEN_OPC_ALU)
) i_alu2 (
    .rs1_exe_req(rs12_exe_req),
    .rs1_id(rs12_id),
    .rs1_opc(rs12_opc),
    .rs1_opr1(rs12_opr1),
    .rs1_opr2(rs12_opr2),
    .alu_resp(alu2_resp),
    .alu_finish(alu2_finish),
    .cdb_ctrl_resp_alu(cdb_ctrl_resp_alu2),
    .alu_data_out(alu2_data_out),
    .*
);

/*------------------------------*/

// RS2 (Branch Unit)
rs2 #(
    .size(SIZE_RS_BR),
    .len_opc(LEN_OPC_BR),
    .len_id(LEN_ID)
) i_rs2 (.*);

// Branch Unit
br #(
    .len_id(LEN_ID),
    .len_opc(LEN_OPC_BR),
    .rob_size(SIZE_ROB)
) i_br (.*);

// Load/Store Unit
lsq #(
    .size(SIZE_RS_LSQ),
    .len_opc(LEN_OPC_LSQ),
    .len_id(LEN_ID) 
) i_lsq (.*);

endmodule : cpu
