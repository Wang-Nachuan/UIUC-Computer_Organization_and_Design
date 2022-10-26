
/**
 * Generates constrained random vectors with which to drive the DUT.
 * Recommended usage is to test arithmetic and comparator functionality,
 * as well as branches.
 *
 * Randomly testing load/stores will require building a memory model,
 * which you can do using a SystemVerilog associative array:
 *     logic[7:0] byte_addressable_mem [logic[31:0]]
 *   is an associative array with value type logic[7:0] and
 *   key type logic[31:0].
 * See IEEE 1800-2017 Clause 7.8
**/
module random_tb
import rv32i_types::*;
(
    tb_itf.tb itf,
    tb_itf.magic_mem mem_itf
);

/**
 * SystemVerilog classes can be defined inside modules, in which case
 *   their usage scope is constrained to that module
 * RandomInst generates constrained random test vectors for your
 * rv32i DUT.
 * As is, RandomInst only supports generation of op_imm opcode instructions.
 * You are highly encouraged to expand its functionality.
**/
class RandomInst;
    rv32i_reg reg_range[$];
    arith_funct3_t arith3_range[$];

    /** Constructor **/
    function new();
        arith_funct3_t af3;
        af3 = af3.first;

        for (int i = 0; i < 32; ++i)
            reg_range.push_back(i);
        do begin
            arith3_range.push_back(af3);
            af3 = af3.next;
        end while (af3 != af3.first);

    endfunction

    function rv32i_word immediate(
        ref rv32i_reg rd_range[$] = reg_range,
        ref arith_funct3_t funct3_range[$] = arith3_range,
        ref rv32i_reg rs1_range[$] = reg_range
    );
        union {
            rv32i_word rvword;
            struct packed {
                logic [31:20] i_imm;
                rv32i_reg rs1;
                logic [2:0] funct3;
                logic [4:0] rd;
                rv32i_opcode opcode;
            } i_word;
        } word;

        word.rvword = '0;
        word.i_word.opcode = op_imm;

        // Set rd register
        do begin
            word.i_word.rd = $urandom();
        end while (!(word.i_word.rd inside {rd_range}));

        // set funct3
        do begin
            word.i_word.funct3 = $urandom();
        end while (!(word.i_word.funct3 inside {funct3_range}));

        // set rs1
        do begin
            word.i_word.rs1 = $urandom();
        end while (!(word.i_word.rs1 inside {rs1_range}));

        // set immediate value
        word.i_word.i_imm = $urandom();

        return word.rvword;
    endfunction

    function rv32i_word register(
        ref rv32i_reg rd_range[$] = reg_range,
        ref arith_funct3_t funct3_range[$] = arith3_range,
        ref rv32i_reg rs1_range[$] = reg_range,
        ref rv32i_reg rs2_range[$] = reg_range
    );
        union {
            rv32i_word rvword;
            struct packed {
                logic [31:25] j_imm;
                logic [24:20] rs2;
                logic [19:15] rs1;
                logic [14:12] funct3;
                logic [11:7] rd;
                logic [6:0] opcode;
            } i_word;
        } word;

        word.rvword = '0;
        word.i_word.opcode = op_reg;

        // Set rd register
        do begin
            word.i_word.rd = $urandom();
        end while (!(word.i_word.rd inside {rd_range}));

        // set rs1
        do begin
            word.i_word.rs1 = $urandom();
        end while (!(word.i_word.rs1 inside {rs1_range}));

        // set rs2
        do begin
            word.i_word.rs2 = $urandom();
        end while (!(word.i_word.rs2 inside {rs2_range}));

        // set funct3
        do begin
            word.i_word.funct3 = $urandom();
        end while (!(word.i_word.funct3 inside {funct3_range}));

        // set j_imm
        word.rvword[30] = $urandom();

        return word.rvword;
    endfunction

endclass

RandomInst generator = new();

int mod1 = 100;
int mod2 = 1000;

task immediate_tests(input int count);

    logic [31:0] inst_temp;
    logic [31:0] inst_count;

    logic [31:0] int_count_addi;
    logic [31:0] int_count_slti;
    logic [31:0] int_count_sltiu;
    logic [31:0] int_count_xori;
    logic [31:0] int_count_ori;
    logic [31:0] int_count_andi;
    logic [31:0] int_count_slli;
    logic [31:0] int_count_srli;
    logic [31:0] int_count_srai;

    // @(posedge itf.clk iff itf.rst == 1'b1);
    // @(mem_itf.mmcb);
    $display("Start Imm-Reg Tests");
    $display("+----------------+--------------+-------+-----+-------+--------+");
    $display("|  Sample Inst   |     i_imm    |  rs1  | fu3 |   rd  | opcode |");
    $display("+----------------+--------------+-------+-----+-------+--------+");
    inst_temp <= generator.immediate();
    inst_count <= 1;
    int_count_addi <= 0;
    int_count_slti <= 0;
    int_count_sltiu <= 0;
    int_count_xori <= 0;
    int_count_ori <= 0;
    int_count_andi <= 0;
    int_count_slli <= 0;
    int_count_srli <= 0;
    int_count_srai <= 0;
    repeat (count) begin
        @(mem_itf.mmcb iff mem_itf.mmcb.read_a);
        mem_itf.mmcb.rdata_a <= inst_temp;
        mem_itf.mmcb.resp_a <= 1;
        // Print
        if (inst_count % mod1 == 0)
            $display(
                "|inst [%9d]| %12b | %5b | %3b | %5b | %7b|", 
                inst_count,
                inst_temp[31:20],
                inst_temp[19:15],
                inst_temp[14:12],
                inst_temp[11:7],
                inst_temp[6:0]
            );
        if (inst_count % mod2 == 0) $display("+----------------+--------------+-------+-----+-------+--------+");
        inst_temp <= generator.immediate();
        // Count
        case (inst_temp[14:12])
            3'b000: int_count_addi <= int_count_addi + 1;
            3'b001: int_count_slli <= int_count_slli + 1;
            3'b010: int_count_slti <= int_count_slti + 1;
            3'b011: int_count_sltiu <= int_count_sltiu + 1;
            3'b100: int_count_xori <= int_count_xori + 1;
            3'b101: begin
                if (inst_temp[30])
                    int_count_srai <= int_count_srai + 1;
                else
                    int_count_srli <= int_count_srli + 1;
            end
            3'b110: int_count_ori <= int_count_ori + 1;
            3'b111: int_count_andi <= int_count_andi + 1;
        endcase
        inst_count <= inst_count + 1;
        @(mem_itf.mmcb) mem_itf.mmcb.resp_a <= 1'b0;
    end
    $display("Inctruction coverage:");
    $display("addi: %d", int_count_addi);
    $display("slti: %d", int_count_slti);
    $display("sltiu: %d", int_count_sltiu);
    $display("xori: %d", int_count_xori);
    $display("ori: %d", int_count_ori);
    $display("andi: %d", int_count_andi);
    $display("slli: %d", int_count_slli);
    $display("srli: %d", int_count_srli);
    $display("srai: %d", int_count_srai);
    $display("Finish Imm-Reg Tests");
endtask

task register_tests(input int count);

    logic [31:0] inst_temp;
    logic [31:0] inst_count;

    logic [31:0] int_count_add;
    logic [31:0] int_count_sub;
    logic [31:0] int_count_sll;
    logic [31:0] int_count_slt;
    logic [31:0] int_count_sltu;
    logic [31:0] int_count_xor;
    logic [31:0] int_count_srl;
    logic [31:0] int_count_sra;
    logic [31:0] int_count_or;
    logic [31:0] int_count_and;
    
    // @(posedge itf.clk iff itf.rst == 1'b1);
    // @(mem_itf.mmcb);
    $display("Start Reg-Reg Tests");
    $display("+----------------+---------+-------+-------+-----+-------+--------+");
    $display("|  Sample Inst   |  j_imm  |  rs2  |  rs1  | fc3 |   rd  | opcode |");
    $display("+----------------+---------+-------+-------+-----+-------+--------+");
    inst_temp <= generator.register();
    inst_count <= 1;
    int_count_add <= 0;
    int_count_sub <= 0;
    int_count_slt <= 0;
    int_count_sltu <= 0;
    int_count_xor <= 0;
    int_count_or <= 0;
    int_count_and <= 0;
    int_count_sll <= 0;
    int_count_srl <= 0;
    int_count_sra <= 0;
    repeat (count) begin
        @(mem_itf.mmcb iff mem_itf.mmcb.read_a);
        mem_itf.mmcb.rdata_a <= inst_temp;
        mem_itf.mmcb.resp_a <= 1;
        // Print
        if (inst_count % mod1 == 0)
            $display(
                "|inst [%9d]| %7b | %5b | %5b | %3b | %5b | %7b|", 
                inst_count,
                inst_temp[31:25],
                inst_temp[24:20],
                inst_temp[19:15],
                inst_temp[14:12],
                inst_temp[11:7],
                inst_temp[6:0]
            );
        if (inst_count % mod2 == 0) $display("+----------------+---------+-------+-------+-----+-------+--------+");
        inst_temp <= generator.register();
        // Count
        case (inst_temp[14:12])
            3'b000: begin
                if (inst_temp[30])
                    int_count_sub <= int_count_sub + 1;
                else
                    int_count_add <= int_count_add + 1;
            end
            3'b001: int_count_sll <= int_count_sll + 1;
            3'b010: int_count_slt <= int_count_slt + 1;
            3'b011: int_count_sltu <= int_count_sltu + 1;
            3'b100: int_count_xor <= int_count_xor + 1;
            3'b101: begin
                if (inst_temp[30])
                    int_count_sra <= int_count_sra + 1;
                else
                    int_count_srl <= int_count_srl + 1;
            end
            3'b110: int_count_or <= int_count_or + 1;
            3'b111: int_count_and <= int_count_and + 1;
        endcase
        inst_count <= inst_count + 1;
        @(mem_itf.mmcb) mem_itf.mmcb.resp_a <= 1'b0;
    end
    $display("Inctruction coverage:");
    $display("add: %d", int_count_add);
    $display("sub: %d", int_count_sub);
    $display("slt: %d", int_count_slt);
    $display("sltu: %d", int_count_sltu);
    $display("xor: %d", int_count_xor);
    $display("or: %d", int_count_or);
    $display("and: %d", int_count_and);
    $display("sll: %d", int_count_sll);
    $display("srl: %d", int_count_srl);
    $display("sra: %d", int_count_sra);
    $display("Finish Reg-Reg Tests");
endtask

initial begin
    itf.rst = 1'b1;
    repeat (5) @(posedge itf.clk);
    itf.rst = 1'b0;
    immediate_tests(10000);
    $display("\n");
    register_tests(10000);
    $finish;
end

endmodule : random_tb


