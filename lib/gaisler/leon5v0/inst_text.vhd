library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library grlib;
use grlib.sparc.all;


entity inst_text is
  port (
    inst : in std_logic_vector(31 downto 0));
  
end inst_text;


architecture behav of inst_text is

  signal info : string(1 to 20);

  function string_fill(msg : string; len : natural) return string is
    variable res_v : string(1 to len);
  begin
    res_v := (others => ' ');  -- Fill with spaces to blank all for a start
    res_v(1 to msg'length) := msg;
    return res_v;
  end function;

begin


  process(inst)
  begin
    case inst(31 downto 30) is
      when "00" =>
        case inst(24 downto 22) is
          when "000" =>
            info <= string_fill("unimp", info'length);
          when "010" =>
            --BICC
            case inst(28 downto 25) is
              when "0000" =>
                if inst(29) = '0' then
                  info <= string_fill("bn", info'length);
                else
                  info <= string_fill("bn,a", info'length);
                end if;
              when "0001" =>
                if inst(29) = '0' then
                  info <= string_fill("be", info'length);
                else
                  info <= string_fill("be,a", info'length);
                end if;
                
              when "0010" =>
                if inst(29) = '0' then
                  info <= string_fill("ble", info'length);
                else
                  info <= string_fill("ble,a", info'length);
                end if;
              when "0011" =>
                if inst(29) = '0' then
                  info <= string_fill("bl", info'length);
                else
                  info <= string_fill("bl,a", info'length);
                end if;
              when "0100" =>
                if inst(29) = '0' then
                  info <= string_fill("bleu", info'length);
                else
                  info <= string_fill("bleu,a", info'length);
                end if;
              when "0101" =>
                if inst(29) = '0' then
                  info <= string_fill("bcs", info'length);
                else
                  info <= string_fill("bcs,a", info'length);
                end if;   
              when "0110" =>
                if inst(29) = '0' then
                  info <= string_fill("bneg", info'length);
                else
                  info <= string_fill("bneg,a", info'length);
                end if;
              when "0111" =>
                if inst(29) = '0' then
                  info <= string_fill("bvs", info'length);
                else
                  info <= string_fill("bvs,a", info'length);
                end if;
                
              when "1000" =>
                if inst(29) = '0' then
                  info <= string_fill("ba", info'length);
                else
                  info <= string_fill("ba,a", info'length);
                end if;
              when "1001" =>
                if inst(29) = '0' then
                  info <= string_fill("bne", info'length);
                else
                  info <= string_fill("bne,a", info'length);
                end if;
              when "1010" =>
                if inst(29) = '0' then
                  info <= string_fill("bg", info'length);
                else
                  info <= string_fill("bg,a", info'length);
                end if;
              when "1011" =>
                if inst(29) = '0' then
                  info <= string_fill("bge", info'length);
                else
                  info <= string_fill("bge,a", info'length);
                end if;  
              when "1100" =>
                if inst(29) = '0' then
                  info <= string_fill("bgu", info'length);
                else
                  info <= string_fill("bgu,a", info'length);
                end if;
              when "1101" =>
                if inst(29) = '0' then
                  info <= string_fill("bcc", info'length);
                else
                  info <= string_fill("bcc,a", info'length);
                end if;
              when "1110" =>
                if inst(29) = '0' then
                  info <= string_fill("bpos", info'length);
                else
                  info <= string_fill("bpos,a", info'length);
                end if;
              when "1111" =>
                if inst(29) = '0' then
                  info <= string_fill("bvc", info'length);
                else
                  info <= string_fill("bvc,a", info'length);
                end if;
              when others =>
                null;
            end case;
          when "100" =>
            info <= string_fill("sethi", info'length);
          when "110" =>
            info <= string_fill("fbfcc", info'length);
          when "111" =>
            info <= string_fill("cbccc", info'length); 
          when others =>
            null;
        end case;
      when "01" =>
        info <= string_fill("call", info'length);
      when "10" =>
        case inst(24 downto 19) is
          when IADD =>
            info <= string_fill("iadd", info'length);
          when IAND =>
            info <= string_fill("iand", info'length);
          when IOR =>
            info <= string_fill("ior", info'length);
          when IXOR =>
            info <= string_fill("ixor", info'length);
          when ISUB =>
            info <= string_fill("isub", info'length);
          when ANDN =>
            info <= string_fill("andn", info'length);
          when ORN =>
            info <= string_fill("orn", info'length);
          when IXNOR =>
            info <= string_fill("ixnor", info'length);
          when ADDX =>
            info <= string_fill("addx", info'length);
          when UMUL =>
            info <= string_fill("umul", info'length);
          when SMUL =>
            info <= string_fill("smul", info'length);
          when SUBX =>
            info <= string_fill("subx", info'length);
          when UDIV =>
            info <= string_fill("udiv", info'length);
          when SDIV =>
            info <= string_fill("sdiv", info'length);
          when ADDCC =>
            info <= string_fill("addcc", info'length);
          when ANDCC =>
            info <= string_fill("andcc", info'length);
          when ORCC =>
            info <= string_fill("orcc", info'length);
          when XORCC =>
            info <= string_fill("xorcc", info'length);
          when SUBCC =>
            info <= string_fill("subcc", info'length);
          when ANDNCC =>
            info <= string_fill("andncc", info'length);
          when ORNCC =>
            info <= string_fill("orncc", info'length);
          when XNORCC =>
            info <= string_fill("xnorcc", info'length);
          when ADDXCC =>
            info <= string_fill("addxcc", info'length);
          when UMULCC =>
            info <= string_fill("umulcc", info'length);
          when SMULCC =>
            info <= string_fill("smulcc", info'length);
          when SUBXCC =>
            info <= string_fill("subxcc", info'length);
          when UDIVCC =>
            info <= string_fill("udivcc", info'length);
          when SDIVCC =>
            info <= string_fill("sdivcc", info'length);
          when MULSCC =>
            info <= string_fill("mulscc", info'length);
          when ISLL =>
            info <= string_fill("isll", info'length);
          when ISRL =>
            info <= string_fill("isrl", info'length);
          when ISRA =>
            info <= string_fill("isra", info'length);
          when RDY =>
            info <= string_fill("rdy", info'length);
          when RDPSR =>
            info <= string_fill("rdpsr", info'length);
          when RDWIM =>
            info <= string_fill("rdwim", info'length);
          when RDTBR =>
            info <= string_fill("rdtbr", info'length);
          when WRY =>
            info <= string_fill("wry", info'length);
          when WRPSR =>
            info <= string_fill("wrpsr", info'length);
          when WRWIM =>
            info <= string_fill("wrwim", info'length);
          when WRTBR =>  
            info <= string_fill("wrtbr", info'length);
          when JMPL =>
            info <= string_fill("jmpl", info'length);         
          when FLUSH =>
            info <= string_fill("flush", info'length);
          when RETT =>
            info <= string_fill("rett", info'length);
          when SAVE =>
            info <= string_fill("save", info'length);
          when RESTORE =>
            info <= string_fill("restore", info'length);
          when others =>
            info <= string_fill("unimp", info'length);
        end case;
      when "11" =>
        --LDST
        case inst(24 downto 19) is
          when LD =>
            info <= string_fill("ld", info'length);
          when LDUB =>
            info <= string_fill("ldub", info'length);            
          when LDUH =>
            info <= string_fill("lduh", info'length);    
          when LDD =>
            info <= string_fill("ldd", info'length);    
          when LDSB =>
            info <= string_fill("ldsb", info'length);    
          when LDSH =>
            info <= string_fill("ldsh", info'length);    
          when LDSTUB =>
            info <= string_fill("ldstub", info'length);    
          when SWAP =>
            info <= string_fill("swap", info'length);    
          when LDA =>
            info <= string_fill("lda", info'length);    
          when LDUBA =>
            info <= string_fill("lduba", info'length);    
          when LDUHA =>
            info <= string_fill("lduha", info'length);    
          when LDDA =>
            info <= string_fill("ldda", info'length);    
          when LDSBA =>
            info <= string_fill("ldsba", info'length);    
          when LDSHA =>
            info <= string_fill("ldsha", info'length);    
          when LDSTUBA =>
            info <= string_fill("ldstuba", info'length);    
          when SWAPA =>
            info <= string_fill("swapa", info'length);    
          when LDF =>
            info <= string_fill("ldf", info'length);    
          when LDFSR =>
            info <= string_fill("ldfsr", info'length);    
          when LDDF =>
            info <= string_fill("lddf", info'length);    
          when LDC =>
            info <= string_fill("ldc", info'length);    
          when LDCSR =>
            info <= string_fill("ldcsr", info'length);    
          when LDDC =>
            info <= string_fill("lddc", info'length);    
          when ST =>
            info <= string_fill("st", info'length);    
          when STB =>
            info <= string_fill("stb", info'length);    
          when STH =>
            info <= string_fill("sth", info'length);    
          when ISTD =>
            info <= string_fill("istd", info'length);    
          when STA =>
            info <= string_fill("sta", info'length);    
          when STBA =>
            info <= string_fill("stba", info'length);    
          when STHA =>
            info <= string_fill("stha", info'length);    
          when STDA =>
            info <= string_fill("stda", info'length);    
          when STF =>
            info <= string_fill("stf", info'length);    
          when STFSR =>
            info <= string_fill("stfsr", info'length);    
          when STDFQ =>
            info <= string_fill("stdfq", info'length);    
          when STDF =>
            info <= string_fill("stdf", info'length);    
          when STC =>
            info <= string_fill("stc", info'length);    
          when STCSR =>
            info <= string_fill("stcsr", info'length);    
          when STDCQ =>
            info <= string_fill("stdcq", info'length);    
          when STDC =>
            info <= string_fill("stdc", info'length);    
          when CASA =>
            info <= string_fill("casa", info'length);    
          when others =>
            info <= string_fill("unimp", info'length);
        end case;
      when others => null;
    end case;



  end process;


end;
  
