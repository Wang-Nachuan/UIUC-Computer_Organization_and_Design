
module cmp
import rv32i_types::*;
(
    input rv32i_word src_a,
    input rv32i_word src_b,
    input branch_funct3_t cmpop,
    output logic br_en
);

always_comb 
begin
    br_en = 1'b0;
    unique case (cmpop)
        beq:   if (src_a == src_b) br_en = 1'b1;
        bne:   if (src_a != src_b) br_en = 1'b1;
        blt:   if ($signed(src_a) < $signed(src_b)) br_en = 1'b1;
        bge:   if ($signed(src_a) >= $signed(src_b)) br_en = 1'b1;
        bltu:  if (src_a < src_b) br_en = 1'b1;
        bgeu:  if (src_a >= src_b) br_en = 1'b1;
    endcase
end

endmodule : cmp