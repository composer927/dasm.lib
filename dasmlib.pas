{
  dasmlib for Delphi
  Author: Hakan DİMDİK
  Created: 01/01/2021
  Last modified: 01/01/2021
}

unit dasmlib;

interface

uses
  System.Classes;

//random 32 bit unsigned integer generator
function rnd(max:cardinal):Cardinal;
//integer to ansistring/zero terminated string
procedure itoa(src:uint64; dst:pansichar);
//Agner Fog's SSE2 strlen function for ansichar array and ansistring
function StrLen(const AStr: PAnsiChar): NativeUInt;
//A SSE2 string copy function for ansichar array and ansistring
function StrCpy(ADest: PAnsiChar ;const ASource: PAnsiChar):NativeUInt;

implementation


{
  Simple random function

  Usage:
  ShowMessage(inttostr(rnd(100)));
  Generates a random number between 0-99
}
function rnd(max:cardinal):Cardinal;
asm
    mov r10d, ecx  //max sayısını r10d'ye alıuyoruz.
    call System.Classes.TThread.GetTickCount //tick sayısını alıyoruz
    mov rcx, rax //rcx'e tick sayısını atıyoruz
    bswap eax  //eax'in bytelarını yer değiştiriyoruz
    mov al, cl   //ilk byte'ı en sona alıyoruz
    xor edx, edx  //bölmede bölünen'i yüsek kısmını sıfırlıyoruz
    div r10d     //max ile tickcount'u bölüyoruz
    mov eax, edx  //bölmeden kalanı result'a atıyoruz
end;

{
  integer to string function
  An alternatif function to delphi's inttostr

  usage:
    procedure Test;
    var
     str:ansistring;
    begin
       SetLength(str,2);
       intoansi(33,pansichar(str));
       write(str);
       SetLength(str,3);
       intoansi(456,pansichar(str));
       write(str);
       Readln;
    end;
}
procedure itoa(src:uint64; dst:pansichar);
asm
   .noframe
   //edx:eax bölünen, kalan dl
   mov eax, ecx   //src'yi eax'e alıyoruz
   mov r9, rdx   //string adresi
   mov r10, 10    //constant 10

   xor r8, r8 //basamak sayısı 0'dan başlıyor, çünkü indeks numarasıyla işlem yapacağız

@basamakLoop:
   xor edx, edx  //dx sıfırlama
   div r10d //eax'i 10'a bölüyoruz
   add r8,1
   cmp eax, 10
   jae @basamakLoop

   mov eax, ecx   //src'yi eax'e tekrar alıyoruz

   cmp eax, r10d  //sayı ondan küçükse sona git
   jb @Ret

@L:
   xor edx, edx  //bölme işleminde kalan kısmı tekrar sıfırlıyoruz
   div r10d //eax'i 10'a bölüyoruz
   //kalanı ekledik
   add dl, 48    //dl'den ascii karakteri elde ediyoruz
   mov [r9+r8], dl
   sub r8, 1
   //bölüm 10'dan küçükse bitir
   cmp eax, r10d
   jb @Ret10
   jmp @L;
@Ret10:
   add al, 48
   mov byte ptr [r9+r8],  al
   ret
@Ret:
   add al, 48  //sayıya 48 eklenince ascii değerini alıyoruz
   mov byte ptr [r9+r8],  al //indekse ascii değeri yaz
end;

{
  Agner Fog's SSE2 strlen function for ansichar array and ansistring
  https://github.com/tpn/agner/tree/master/asmlib
  usage:

  var
    len:integeR;
    str:ansistring
    ...
    len= strlen(pansichar(str));
}
function StrLen(const AStr: PAnsiChar): NativeUInt;
asm
   .noframe
   mov      rax,  rcx      //; string'in pointerini alıyoruz
   mov      r8,   rcx      //; string'in pointerini kopyalıyoruz

   //; rax = s, ecx = 32 bits of s
   pxor     xmm0, xmm0    //; xmm0 registerini sıfırlıyoruz
   and      ecx,  0FH     //; lower 4 bits indicate misalignment
   and      rax,  -10H    //; align pointer by 16
   movdqa   xmm1, [rax]   //; read from nearest precedingboundary
   pcmpeqb  xmm1, xmm0    //; compare 16 bytes with zero
   pmovmskb edx,  xmm1    //; get one bit for each byte result
   shr      edx,  cl      //        ; shift out false bits
   shl      edx,  cl      //        ; shift back again
   bsf      edx,  edx     //        ; find first 1-bit
   jnz      @L2            //        ; found

   //; Main loop, search 16 bytes at a time
@L1: add     rax,  10H     //        ; increment pointer by 16
   movdqa   xmm1, [rax]   //        ; read 16 bytes aligned
   pcmpeqb  xmm1, xmm0    //        ; compare 16 bytes with zero
   pmovmskb edx,  xmm1    //        ; get one bit for each byte result
   bsf      edx,  edx     //        ; find first 1-bit
   //; (moving the bsf out of the loop and using test here would be faster for long strings on old processors,
   //;  but we are assuming that most strings are short, and newer processors have higher priority)
   jz       @L1
@L2:     //; Zero-byte found. Compute string length
   sub      rax,  r8   //      ; subtract start address
   add      rax,  rdx       //      ; add byte index
   ret

end;

{
    SSE2 move functions from Pierre le Riche's Fastmm4 functions
}
procedure Move16(const ASource; var ADest; ACount: NativeInt);
asm
    .noframe
    movdqu xmm0, [rcx]  //sse2 xmm0 registerine alıyoruz.  unaligned version: rem to reg
    movdqu [rdx], xmm0  //dest'e de xmm0'dakini atıyoruz.
end;
procedure MoveMultipleOf16(const ASource; var ADest; ACount: NativeInt);
asm
  .noframe
  add rcx, r8
  add rdx, r8
  neg r8
@MoveLoop:
  movdqu xmm0, [rcx + r8]
  movdqu [rdx + r8], xmm0
  add r8, 16
  js @MoveLoop
end;

{
    A SSE2 string copy function for ansichar array and ansistring
    It returns copied string length
    Uses Pierre le Riche's Fastmm4 functions

    Usage 1 :
      var
      str:ansistring;
      ...
      SetLength(str,20);
      StrCpy(pansichar(str),Pansichar('test'));

    Usage 2 :
      type
        TStr=  array[0..200] of AnsiChar;

      var
        a: TStr ;
        b: TStr ;
        c: NativeUint;
      begin
        try


           a:='fhakanzzzzddxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxaa';

           writeln('Hakan length: ' +inttostr(strlen(a)));
           c:=StrCpy(b,a);
           writeln('b=: ' +b+' len:='+inttostr( c ));
           Readln;
        except
          on E: Exception do
            Writeln(E.ClassName, ': ', E.Message);
        end;
      end.
}
function StrCpy(ADest: PAnsiChar ;const ASource: PAnsiChar):NativeUInt;
asm
    .noframe
    lea r10, [rcx]    //adest'i alıyoruz
    lea r11, [rdx]    //asource'u alıyoruz

    mov rcx, r11  //source'u rcx'e aldık
    call StrLen     //rax'e uzunluk atandı

    mov rcx, r11   //ilk parametre: source
    mov rdx, r10   //ikinci parametre:destination
    mov r8, rax    //uzunluğu r8'e aldık

    cmp r8, 10h  //boyut 16'dan küçük mü?
    jb @LessThen16  //küçükse move16'ya git
    call MoveMultipleOf16
    //mov rax, r8
    ret
@LessThen16:
    call Move16
    //mov rax, r8
end;


end.
