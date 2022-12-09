module cacheline_adaptor
(
    input clk,
    input reset_n,

    // Port to LLC (Lowest Level Cache)
    input logic [255:0] line_i,
    output logic [255:0] line_o,
    input logic [31:0] address_i,
    input read_i,
    input write_i,
    output logic resp_o,

    // Port to memory
    input logic [63:0] burst_i,
    output logic [63:0] burst_o,
    output logic [31:0] address_o,
    output logic read_o,
    output logic write_o,
    input resp_i
);

    typedef enum bit [2:0] 
    {initial_state, waitread, waitwrite, read, write, finish} 
    cacheline_state;
    cacheline_state state;
    logic [1:0] count;
    localparam logic [1:0] maxcount = 2'b11;


    logic [255:0] line_buffer;
    logic [31:0] address_buffer;
    enum bit [1:0] {read_operation, write_operation, no_operation} operation;

    assign line_o = line_buffer;
    assign address_o = address_buffer;
    assign burst_o = line_buffer[64*count +: 64];
    assign read_o = (state == waitread) || (state == read);
    assign write_o = (state == waitwrite) || (state == write);
    assign resp_o = (state == finish)? 1'b1:1'b0;


    always_ff @(posedge clk) begin
        if (~reset_n) begin
            state <= initial_state;
        end
        else begin
            case (state)
            initial_state: begin
                case (operation)
                    write_operation: begin
                        count <= 2'b00;
                        state <= waitwrite;
                        line_buffer <= line_i;
                        address_buffer <= address_i;
                    end
                    read_operation: begin
                        state <= waitread;
                        address_buffer <= address_i;
                    end
                    no_operation: ;

                endcase
            end
            waitread: begin
                if (resp_i) begin
                    state <= read;
                    count <= 2'b01;
                    line_buffer[63:0] <= burst_i;
                end
            end
            waitwrite: begin
                if (resp_i) begin
                    state <= write;
                    count <= 2'b01;
                end
            end
            read: begin
                if (count == maxcount) begin
                    state <= finish;
                end
                line_buffer[64*count +: 64] <= burst_i;
                count <= count + 2'b01;
            end
            write: begin
                if (count == maxcount) begin
                    state <= finish;
                end
                count <= count + 2'b01;
            end
            finish: begin
                state <= initial_state;
            end
            endcase
        end
    end

    always_comb begin
        operation=no_operation;
        if (read_i==1)begin
        operation=read_operation;
        end
        else if(write_i==1)begin
        operation=write_operation;
        end
    end

endmodule : cacheline_adaptor
