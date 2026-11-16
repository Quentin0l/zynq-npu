// main.c : premier contact avec le NPU , sur la carte.
// Provenance : leçon 4 du parcours « NPU sur ZedBoard » (squelette ; TODO 1 à 3
// à écrire par l'auteur du dépôt).
#include <stdio.h>
#include "xil_io.h"     // Xil_In32, Xil_Out32, Xil_Out8 : accès volatile
#include "xiltimer.h"   // XTime_GetTime, COUNTS_PER_SECOND : le temporisateur de l'ARM

// L'IP du NPU n'a pas de pilote : son adresse n'est pas dans xparameters.h.
// On la recopie de l'Address Editor (leçon 3).
#define NPU_BASEADDR 0x40000000u
#define NPU_VERSION  0x00u   // L    « NPU » en ASCII, puis la version
#define NPU_SCRATCH  0x04u   // L/É  ce que l'ARM y a écrit
#define NPU_CYCLES   0x08u   // L    fronts d'axi_aclk depuis le reset

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);   // chaque printf part tout de suite sur l'UART
    printf("\r\n=== NPU (coquille) sur ZedBoard ===\r\n");

    // TODO 1 : lis VERSION avec Xil_In32, affiche-le en hexadécimal, puis ses
    //          trois octets de poids fort comme des caractères et l'octet de
    //          poids faible comme un nombre. Attendu : VERSION = 0x4E505501 : NPU v1
    u32 version = Xil_In32(NPU_BASEADDR + NPU_VERSION);
    printf("VERSION = 0x%08lx : %c%c%c v%lu\r\n", version,
       (char)((version >> 24) & 0xFF),     // 'N' : version[31:24]
       (char)((version >> 16) & 0xFF),     // 'P'
       (char)((version >> 8) & 0xFF),     // 'U'
       version & 0xFF);                    // 1 
    
    
    // TODO 2 : écris 0xDEADBEEF dans SCRATCH (Xil_Out32) et relis-le. Puis écris
    //          le seul octet 0x22 à l'adresse SCRATCH + 2 (Xil_Out8), et relis le
    //          mot entier. Attendu : 0xDEADBEEF, puis 0xDE22BEEF.

    Xil_Out32(NPU_BASEADDR + NPU_SCRATCH, 0xDEADBEEF);
    printf("SCRATCH = 0x%08lx\r\n", Xil_In32(NPU_BASEADDR + NPU_SCRATCH));
    Xil_Out8(NPU_BASEADDR + NPU_SCRATCH + 2, 0x22);
    printf("SCRATCH = 0x%08lx (octet 2 seul)\r\n", Xil_In32(NPU_BASEADDR + NPU_SCRATCH));

    
    // TODO 3 : la fréquence de FCLK_CLK0. Lis CYCLES, attends une seconde au
    //          temporisateur de l'ARM (XTime_GetTime, jusqu'à COUNTS_PER_SECOND
    //          ticks), relis CYCLES : la différence est la fréquence, en Hz.
    //          Piège connu : COUNTS_PER_SECOND est une macro sans parenthèses.
    //          Copie-la d'abord dans une variable : const XTime cps = COUNTS_PER_SECOND;

    const XTime cps = COUNTS_PER_SECOND;    // ticks par seconde
    XTime t0, t1;
    XTime_GetTime(&t0);
    u32 c0 = Xil_In32(NPU_BASEADDR + NPU_CYCLES);
    do {
        XTime_GetTime(&t1);
    } while (t1 - t0 < cps);                // tant qu'une seconde n'est pas passée
    u32 c1 = Xil_In32(NPU_BASEADDR + NPU_CYCLES);
    printf("FCLK_CLK0 = %lu Hz\r\n", c1 - c0);

    printf("Fin.\r\n");
    return 0;
}