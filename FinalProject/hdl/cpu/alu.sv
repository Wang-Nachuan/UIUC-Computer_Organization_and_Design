module alu 
import rv32i_types::*;
#(
    parameter len_id = LEN_ID,
    parameter len_opc = LEN_OPC_ALU
)
(
    // RS
    input logic rs1_exe_req,
    input logic [len_id-1:0] rs1_id,
    input logic [len_opc-1:0] rs1_opc,
    input logic [31:0] rs1_opr1,
    input logic [31:0] rs1_opr2,
    output logic alu_resp,
    output logic alu_finish,

    // CDB
    input cdb_flush cdb_flush_out,
    input logic cdb_ctrl_resp_alu,      // 1-if get the control of cdb in this cycle
    output cdb_data alu_data_out
);

always_comb begin
    unique case (rs1_opc)
        alu_add:    alu_data_out.data = rs1_opr1 + rs1_opr2;
        alu_sll:    alu_data_out.data = rs1_opr1 << rs1_opr2[4:0];
        alu_sra:    alu_data_out.data = $signed(rs1_opr1) >>> rs1_opr2[4:0];
        alu_sub:    alu_data_out.data = rs1_opr1 - rs1_opr2;
        alu_xor:    alu_data_out.data = rs1_opr1 ^ rs1_opr2;
        alu_srl:    alu_data_out.data = rs1_opr1 >> rs1_opr2[4:0];
        alu_or:     alu_data_out.data = rs1_opr1 | rs1_opr2;
        alu_and:    alu_data_out.data = rs1_opr1 & rs1_opr2;
        alu_slt:    alu_data_out.data = ($signed(rs1_opr1) < $signed(rs1_opr2)) ? 32'b1 : 32'b0;
        alu_sltu:   alu_data_out.data = (rs1_opr1 < rs1_opr2) ? 32'b1 : 32'b0;
        alu_lui:    alu_data_out.data = rs1_opr2;
        alu_auipc:  alu_data_out.data = rs1_opr1 + rs1_opr2;
        default: ;
    endcase

    alu_data_out.id = rs1_id;

    if (cdb_flush_out.en && cdb_flush_out.en_id[rs1_id]) begin
        alu_resp = 1'b0;
        alu_finish = 1'b0;
        alu_data_out.valid = 1'b0;
    end
    else begin
        alu_resp = cdb_ctrl_resp_alu;
        alu_finish = cdb_ctrl_resp_alu & rs1_exe_req;
        alu_data_out.valid = rs1_exe_req;
    end
end

endmodule : alu