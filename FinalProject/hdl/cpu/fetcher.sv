module fetcher 
import rv32i_types::*;
#(parameter width = 32)
( 
    input logic clk,
    input logic rst,

    //from / to inst queue
    input logic iq_isfull,
    output logic [width-1:0] fetch_inst,
    output rv32i_word fetch_pc_next,
    output rv32i_word fetch_pc,
    output logic fetch_wen_inst, // inst valid
    // output logic need_jump, // 
    //branch predict
    input rv32i_word br_addr,
    // input rv32i_word jalr_predicted,
    //from / to cache
    output logic inst_read,
    output rv32i_word inst_mem_address, // address into cache
    input logic inst_mem_resp,
    input logic [width-1:0] inst_mem_rdata,

    //flush
    input logic flush  // flush means mispredicted.
);


assign fetch_pc = inst_mem_address;
assign fetch_inst = inst_mem_rdata;
//assign fetch_wen_inst = ~flush;
// assign inst_read = ~iq_isfull;

rv32i_opcode opcode;
rv32i_word b_imm;
rv32i_word i_imm;
rv32i_word j_imm;

// TO-DO
// logic need_jump; // if predicted to jump
rv32i_word jarl_predicted;

assign opcode = rv32i_opcode'(inst_mem_rdata[6:0]); // 32 bit now
assign b_imm = {{20{inst_mem_rdata[31]}}, inst_mem_rdata[7], inst_mem_rdata[30:25], inst_mem_rdata[11:8], 1'b0};
assign i_imm = {{21{inst_mem_rdata[31]}}, inst_mem_rdata[30:20]};
assign j_imm = {{12{inst_mem_rdata[31]}}, inst_mem_rdata[19:12], inst_mem_rdata[20], inst_mem_rdata[30:21], 1'b0};

// pc_next 
always_comb begin
    // case (opcode) 
    // op_br: if (need_jump) begin
    //         fetch_pc_next = fetch_pc + b_imm;
    //     end
    //     else begin
    //         fetch_pc_next = fetch_pc + 4;
    //     end
    // op_jal: fetch_pc_next = fetch_pc + j_imm;
    // op_jalr: fetch_pc_next = fetch_pc + jalr_predicted;
    // default: fetch_pc_next = fetch_pc + 4;
    // endcase
    fetch_pc_next = fetch_pc + 4;
end

always_ff @(posedge clk) begin
    if (rst) begin
        inst_mem_address <= 32'h00000060;
    end
    else if(flush) begin
        inst_mem_address <= br_addr;
    end
    else begin
        if(inst_mem_resp) begin
            inst_mem_address <= fetch_pc_next;
        end
        else begin
            inst_mem_address <= inst_mem_address;
        end
    end
end

// incorrect implementation if flush for a second, we have to make sure next resp 
always_comb begin
    inst_read = 1'b0;
    fetch_wen_inst = 1'b0;
    if ((~flush) & (~iq_isfull)) begin
        inst_read = 1'b1;
        if (inst_mem_resp)
            fetch_wen_inst = 1'b1;
    end
end

endmodule : fetcher