module inst_queue 
import rv32i_types::*;
#(
    parameter depth = SIZE_INSTQ,
    parameter width = LEN_INSTQ,
    parameter size_br_his = SIZE_GLOBAL
)
(
    input logic clk,
    input logic rst,
    // from /to fetcher
    input logic fetch_wen_inst,
    input rv32i_word fetch_pc_next,
    input rv32i_word fetch_pc,
    input rv32i_word fetch_inst,
    input logic [size_br_his-1:0] fetch_br_history,
    output logic iq_isfull,
    // from and to issuer
    input logic issue_req,
    output rv32i_word iq_inst,
    output rv32i_word iq_pc,
    output rv32i_word iq_pc_next,
    output logic [size_br_his-1:0] iq_br_history,
    output logic iq_rvalid, 
    output logic iq_isempty,

    input logic flush
);
logic [$clog2(depth):0] count;
logic [$clog2(depth)-1:0] wr_ptr; 
logic [$clog2(depth)-1:0] rd_ptr;
// logic [width:0] data_out;
// logic [width:0] regs [0:depth-1]; 
// logic [width:0] data_in;
// correct
// logic [107:0] data_out;             // LEN_INSTQ
// logic [107:0] regs [0:depth-1];     // LEN_INSTQ
// logic [107:0] data_in;              // LEN_INSTQ
logic [LEN_INSTQ:0] data_out;             // LEN_INSTQ
logic [LEN_INSTQ:0] regs [0:depth-1];     // LEN_INSTQ
logic [LEN_INSTQ:0] data_in;              // LEN_INSTQ

assign data_in = {fetch_br_history,fetch_inst, fetch_pc, fetch_pc_next};
assign iq_isfull = (count == depth[$clog2(depth):0]) ? 1'b1 : 1'b0;
assign iq_isempty = (count == {($clog2(depth)+1){1'b0}}) ? 1'b1 : 1'b0;

//correct
// assign iq_br_history = data_out[107:96]; // LEN_INSTQ
assign iq_br_history = data_out[LEN_INSTQ:96]; // LEN_INSTQ

// assign iq_br_history = data_out[width:96];
assign iq_inst = data_out[95:64];
assign iq_pc = data_out[63:32];
assign iq_pc_next = data_out[31:0];

always_ff @(posedge clk) begin
    if(rst | flush) begin
        count <= {($clog2(depth)+1){1'b0}};
    end
    else begin
        case({fetch_wen_inst,issue_req})
            2'b00: count <= count;
            2'b01: count <= count - {{$clog2(depth){1'b0}}, 1'b1};
            2'b10: count <= count + {{$clog2(depth){1'b0}}, 1'b1};
            2'b11 : count <= count;
        endcase
    end
end

// write pointer set and write 
always_ff @(posedge clk) begin
    if(rst | flush) begin
        wr_ptr <= {$clog2(depth){1'b0}};
    end
    else if(fetch_wen_inst && ~iq_isfull) begin
        regs [wr_ptr] <= data_in;
        wr_ptr <= wr_ptr + {{($clog2(depth)-1){1'b0}}, 1'b1};
    end 
end

always_comb begin
    iq_rvalid = ~iq_isempty & ~flush;
    data_out = regs[rd_ptr];
end

//read 
always_ff @(posedge clk) begin
    if(rst | flush)
        rd_ptr <= {$clog2(depth){1'b0}};
    else if(issue_req && ~iq_isempty)
        rd_ptr <= rd_ptr + {{($clog2(depth)-1){1'b0}}, 1'b1};
    else
        rd_ptr <= rd_ptr;
end

endmodule : inst_queue