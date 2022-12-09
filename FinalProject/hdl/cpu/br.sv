/* Branch unit
*/

module br
import rv32i_types::*;
#(
    parameter len_id = LEN_ID,
    parameter len_opc = LEN_OPC_BR,
    parameter rob_size = SIZE_ROB
)(
    // RS
    input logic rs2_exe_req,
    input logic [len_id-1:0] rs2_id,
    input logic [len_opc-1:0] rs2_opc,
    input logic [31:0] rs2_opr1,
    input logic [31:0] rs2_opr2,
    input logic [31:0] rs2_imm,
    input logic [31:0] rs2_pc,
    input logic [SIZE_GLOBAL-1:0] rs2_br_history,
    output logic br_resp,
    output logic br_finish,
    output logic [SIZE_GLOBAL-1:0] br_history_old,
    output logic br_en,
    output logic br_op,
    // CDB
    input cdb_flush cdb_flush_out,
    input logic cdb_ctrl_resp_br,      // 1-if get the control of cdb in this cycle
    output cdb_data br_data_out,

    // ROB
    output logic br_valid,
    output logic [$clog2(rob_size)-1:0] br_id,    // Id of branch instruction
    output logic [31:0] br_addr,
    output logic [31:0] br_pc                     // For branch predictor
);

// logic br_en;      // 1-Branch is taken
logic [31:0] br_addr_i;     // Branch address
logic [31:0] nbr_addr_i;    // PC + 4
// rs2_opc ? op_br -> send to br_predictor
always_comb begin
    br_op = 1'b0;
    unique case (rs2_opc)
        br_jal:br_op = 1'b0;
        br_jalr:br_op = 1'b0;
        default: br_op = 1'b1;
    endcase
end
always_comb begin
    // Branch or not
    br_en = 1'b0;
    unique case (rs2_opc)
        br_beq:     br_en = (rs2_opr1 == rs2_opr2) ? 1'b1 : 1'b0;
        br_bne:     br_en = (rs2_opr1 != rs2_opr2) ? 1'b1 : 1'b0;
        br_blt:     br_en = ($signed(rs2_opr1) < $signed(rs2_opr2)) ? 1'b1 : 1'b0;
        br_bge:     br_en = ($signed(rs2_opr1) >=  $signed(rs2_opr2)) ? 1'b1 : 1'b0;
        br_bltu:    br_en = (rs2_opr1 < rs2_opr2) ? 1'b1 : 1'b0;
        br_bgeu:    br_en = (rs2_opr1 >= rs2_opr2) ? 1'b1 : 1'b0;
        br_jal:     br_en = 1'b1;
        br_jalr:    br_en = 1'b1;
        default: ;
    endcase

    // Branch address
    nbr_addr_i = rs2_pc + 4;
    if (rs2_opc == br_jalr)
        br_addr_i = rs2_opr1 + rs2_imm;
    else
        br_addr_i = rs2_pc + rs2_imm;

    // Output (CDB)
    br_data_out.id = rs2_id;
    br_data_out.data = nbr_addr_i;      // ?
    if (cdb_flush_out.en && cdb_flush_out.en_id[rs2_id]) begin
        br_resp = 1'b0;
        br_finish = 1'b0;
        br_data_out.valid = 1'b0;
    end
    else begin
        br_resp = cdb_ctrl_resp_br;
        br_finish = cdb_ctrl_resp_br & rs2_exe_req;
        br_data_out.valid = rs2_exe_req;
    end
end

// Output (ROB)
assign br_valid = rs2_exe_req;
assign br_id = rs2_id;
assign br_addr = br_en ? {br_addr_i[31:1], 1'b0} : nbr_addr_i;
assign br_pc = rs2_pc;

assign br_history_old = rs2_br_history;

endmodule : br