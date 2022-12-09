module fetcher 
import rv32i_types::*;
#(  parameter width = 32,
    parameter width_rdata = 64,
    parameter size_br_his = SIZE_GLOBAL
)
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
    input logic [63:0] inst_mem_rdata,
    
    //flush and branch
    input logic br_valid,
    input logic [31:0] br_pc,
    input logic br_en, //br taken
    input logic br_op, //opcode == br
    input logic flush, // flush means mispredicted.
    input logic [size_br_his-1:0] br_history_old,
    output logic [size_br_his-1:0] fetch_br_history
);
rv32i_word pc_left; 
rv32i_word inst_left;
logic pc_next_indata;
logic pc_in_q; // fetch_pc already in Q
rv32i_word fetch_pc_next_next;
rv32i_word inst_mem_address_next;
rv32i_word fetch_inst_next;
//buffer
logic [63:0] inst_mem_rdata_buffer;
rv32i_word fetch_pc_next_buffer;
rv32i_word fetch_pc_next_next_buffer;
rv32i_word inst_mem_address_buffer;

logic position;
// buffer,fetch_pc_next, fetch_pc_next_next,position 用来存储fetch pc取64位中的哪部分位置，inst_mem_address_buffer
always_ff @(posedge clk) begin
    if(rst) begin
        fetch_pc_next_buffer <= 32'h00000060;
        fetch_pc_next_next_buffer <= 32'h00000060;
        inst_mem_rdata_buffer <= 64'b0;
        position <= 1'b0;
        inst_mem_address_buffer <= 32'h00000060;
    end
    else begin
        inst_mem_address_buffer <= inst_mem_address; //每一个clk更新inst_mem_address buffer
        if(inst_mem_resp) begin //每次有新的读取，更新所有其他buffer并且根据fetch_pc的位，确定position
            fetch_pc_next_buffer <= fetch_pc_next;
            fetch_pc_next_next_buffer <= fetch_pc_next_next;
            inst_mem_rdata_buffer <= inst_mem_rdata;
            if(fetch_pc[2]) begin
                position <= 1'b1;
            end
            else begin
                position <= 1'b0;
            end
        end
    end
end
always_comb begin // fetch_pc,fetch_inst,fetch_pc_next, fetch_inst_next, inst_mem_address_next
    inst_mem_address_next = fetch_pc_next_buffer;
    if (inst_mem_resp) begin  //更新fetch_pc, fetch_inst,另一个pc(pc_left),inst_left(rdata的另一部分)
        fetch_pc = inst_mem_address;
        if(fetch_pc[2]) begin
            fetch_inst = inst_mem_rdata[63:32];
            pc_left = inst_mem_address - 4;
            inst_left = inst_mem_rdata[31:0];
        end
        else begin
            fetch_inst = inst_mem_rdata[31:0];
            pc_left = inst_mem_address + 4;
            inst_left = inst_mem_rdata[63:32];
        end
        if(pc_left == fetch_pc_next) begin
            // pc_next_indata = 1'b1; //important put into ff
            fetch_inst_next = inst_left;
            //inst_mem_address_next = fetch_pc_next_next_buffer; //buffer
        end
    end
    else begin //pc_next_indata 在inst_mem_resp的时候就被设置了
        // if(pc_next_indata) begin  // pc_next_indata用来判断是否，pc_next在数据中因为是在~inst_mem_resp判断，所以可以用register的数据
        //     //inst_mem_address_next = fetch_pc_next_next_buffer; //如果pc_next在数据中，inst_mem_address_next就应该是pc_next_next
        //     if(position)begin
        //         fetch_inst_next = inst_mem_rdata_buffer[31:0];
        //     end
        //     else begin
        //         fetch_inst_next = inst_mem_rdata_buffer[31:0];
        //     end
        // end
        // else begin
        //     inst_mem_address_next = fetch_pc_next_buffer;
        // end
        if(pc_in_q) begin  //pc in Queue, fetch_inst_next, don't care
            if(pc_next_indata) begin
                fetch_pc = fetch_pc_next_buffer;
                if(position)begin
                    fetch_inst = inst_mem_rdata_buffer[31:0];
                end
                else begin
                    fetch_inst = inst_mem_rdata_buffer[63:32];
                end
            end
            else begin
                fetch_pc = inst_mem_address_buffer; // keep
            end
        end
        else begin
            fetch_pc = inst_mem_address_buffer;
            if(position)begin
                fetch_inst = inst_mem_rdata_buffer[63:32];
            end
            else begin
                fetch_inst = inst_mem_rdata_buffer[31:0];
            end
        end
    end
end



always_ff @(posedge clk) begin 
    if (rst | flush) begin
    pc_next_indata <= 1'b0;
    pc_in_q <= 1'b0;
    // pc_next_in_q <= 1'b0;        
    end
    if(inst_mem_resp) begin
        if(pc_left == fetch_pc_next)begin
            pc_next_indata <= 1'b1;      
        end
        else begin
            pc_next_indata <= 1'b0;  
        end
        if(fetch_wen_inst) begin
            pc_in_q <= 1'b1;
        end
        else begin
            pc_in_q <= 1'b0;
        end
    end
    else begin
        if(fetch_wen_inst) begin
            if(~pc_in_q) begin
                pc_in_q <= 1'b1;
            end
            else begin
                pc_next_indata <= 1'b0;
            end
        end
    end
end
rv32i_opcode fetch_opcode;


// assign fetch_inst = inst_mem_rdata;
//assign fetch_wen_inst = ~flush;
// assign inst_read = ~iq_isfull;
rv32i_opcode opcode_pc_next;
rv32i_word b_imm_pc_next;
rv32i_word i_imm_pc_next;
rv32i_word j_imm_pc_next;

// TO-DO
logic need_jump; // if predicted to jump
logic need_jump_pc_next; //if predicted pc_next need_jump

logic predicting;
logic pred_correct;
logic [width_rdata-1:0] rdata_buffer;

logic predicting_pc_next;
assign predicting_pc_next = (opcode_pc_next == op_br) ? 1'b1:1'b0;
assign opcode_pc_next = rv32i_opcode'(fetch_inst_next[6:0]); // 32 bit now
assign b_imm_pc_next = {{20{fetch_inst_next[31]}}, fetch_inst_next[7], fetch_inst_next[30:25], fetch_inst_next[11:8], 1'b0};
assign i_imm_pc_next = {{21{fetch_inst_next[31]}}, fetch_inst_next[30:20]};
assign j_imm_pc_next = {{12{fetch_inst_next[31]}}, fetch_inst_next[19:12], fetch_inst_next[20], fetch_inst_next[30:21], 1'b0};

// pc_next 
// always_comb begin
//     case (opcode_pc_next) 
//     op_br: if (need_jump_pc_next) begin
//             fetch_pc_next_next = fetch_pc_next + b_imm_pc_next;
//         end
//         else begin
//             fetch_pc_next_next = fetch_pc_next + 4;
//         end
//     op_jal: fetch_pc_next_next = fetch_pc_next + j_imm_pc_next;
//     // op_jalr: fetch_pc_next = fetch_pc + jalr_predicted;
//     default: fetch_pc_next_next = fetch_pc_next + 4;
//     endcase
//     // fetch_pc_next = fetch_pc + 4;
// end
rv32i_opcode opcode;
rv32i_word b_imm;
rv32i_word i_imm;
rv32i_word j_imm;


assign predicting = (opcode == op_br) ? 1'b1:1'b0;
assign pred_correct = ~flush;


assign opcode = rv32i_opcode'(fetch_inst[6:0]); // 32 bit now
assign b_imm = {{20{fetch_inst[31]}}, fetch_inst[7], fetch_inst[30:25], fetch_inst[11:8], 1'b0};
assign i_imm = {{21{fetch_inst[31]}}, fetch_inst[30:20]};
assign j_imm = {{12{fetch_inst[31]}}, fetch_inst[19:12], fetch_inst[20], fetch_inst[30:21], 1'b0};

logic pc_next_predicted;
logic predicted_buffer;
always_ff @(posedge clk) begin
    if(rst) begin
        pc_next_predicted <= 1'b0;
        predicted_buffer <= 1'b0;
    end
    if(predicting_pc_next) begin
        pc_next_predicted <= 1'b1;
        predicted_buffer <= need_jump_pc_next;
    end
    else if(predicting) begin
        pc_next_predicted <= 1'b0;
        predicted_buffer <= 1'b0;
    end
end
// pc_next 
logic pc_need_jump;
always_comb begin
    if(pc_next_predicted) begin
        pc_need_jump = predicted_buffer;
    end
    else begin
        pc_need_jump = need_jump;
    end
    case (opcode) 
    op_br: if (pc_need_jump) begin
            fetch_pc_next = fetch_pc + b_imm;
        end
        else begin
            fetch_pc_next = fetch_pc + 4;
        end
    op_jal: fetch_pc_next = fetch_pc + j_imm;
    // op_jalr: fetch_pc_next = fetch_pc + jalr_predicted;
    default: fetch_pc_next = fetch_pc + 4;
    endcase
    case (opcode_pc_next) 
    op_br: if (need_jump_pc_next) begin
            fetch_pc_next_next = fetch_pc_next + b_imm_pc_next;
        end
        else begin
            fetch_pc_next_next = fetch_pc_next + 4;
        end
    op_jal: fetch_pc_next_next = fetch_pc_next + j_imm_pc_next;
    // op_jalr: fetch_pc_next = fetch_pc + jalr_predicted;
    default: fetch_pc_next_next = fetch_pc_next + 4;
    endcase
    // fetch_pc_next = fetch_pc + 4;
end

//
logic read_delay;
logic read_delay_next;
logic flush_buffer;
rv32i_word br_addr_buffer;

always_ff @(posedge clk) begin
    if (rst) begin
        inst_mem_address <= 32'h00000060;
        read_delay <= 1'b0;
        flush_buffer <= 1'b0;
        br_addr_buffer <= 32'h00000060;
    end
    else if(flush & (~read_delay)) begin // and after get inst_mem_resp
        inst_mem_address <= br_addr;
        br_addr_buffer <= br_addr;
        flush_buffer <= 1'b0;
        read_delay <= 1'b0;
    end
    else if (flush_buffer & (~read_delay)) begin
        inst_mem_address <= br_addr_buffer;
        br_addr_buffer <= br_addr_buffer;
        flush_buffer <= 1'b0;
        read_delay <= 1'b0;
    end
    else begin // without flush, update address and read delay according to read_delay next
        read_delay <= read_delay_next;
        if(inst_mem_resp &(~iq_isfull)) begin
            if(pc_left == fetch_pc_next) begin
                inst_mem_address <= fetch_pc_next_next;
            end
            else begin
                inst_mem_address <= fetch_pc_next;
            end
        end
        else begin
            inst_mem_address <= inst_mem_address;
        end
        if(flush) begin // if flush and write miss, we buffer the flush and br_address
            flush_buffer <= flush;
            br_addr_buffer <= br_addr;
        end
    end 
end
// after flush, 
// incorrect implementation if flush for a second, we have to make sure next resp 
always_comb begin
    read_delay_next = read_delay;
    inst_read = 1'b0;
    fetch_wen_inst = 1'b0;
    unique case (read_delay)
    1'b0: //
    begin
        if((~flush)&(~flush_buffer)&(~iq_isfull)&(~rst)) begin // keep read, judge iq is not full than go to 1'b1;
            if (inst_mem_resp) begin
                fetch_wen_inst = 1'b1;
                inst_read = 1'b1;
                read_delay_next = 1'b0;
            end
            else begin
                if(pc_next_indata & pc_in_q) begin //pc_next go to q
                    inst_read = 1'b1;
                    fetch_wen_inst = 1'b1;
                    read_delay_next = 1'b0;
                end
                else begin
                inst_read = 1'b1;
                read_delay_next = 1'b1;
                end
            end
        end
    end
    1'b1: begin // without feedback, keep reading 
        inst_read = 1'b1;
        if(inst_mem_resp) begin
            read_delay_next = 1'b0;
            if(flush || flush_buffer) begin
                fetch_wen_inst = 1'b0;
            end
            else begin
                fetch_wen_inst = 1'b1;
            end
        end
    end
    default: ;
    endcase
end

br_predictor i_br_predictor(
    .clk(clk),
    .rst(rst),
    .predicting(predicting),
    .fetch_pc(fetch_pc),
    .need_jump(need_jump),

    .predicting_pc_next(predicting_pc_next),
    .fetch_pc_next(fetch_pc_next),
    .need_jump_next(need_jump_pc_next),    

    .updating(br_valid),
    .update_pc(br_pc),
    .br_en(br_en),
    .br_op(br_op),
    .br_history_new(fetch_br_history),
    .br_history_old(br_history_old),
    .pred_correct(pred_correct)
);


endmodule : fetcher