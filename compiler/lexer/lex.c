/* ---------------------------------------------------------------------------
 * Leçon 2 — Squelette de lexer pour un sous-ensemble de C.
 *
 * Ton travail : remplir les quatre TODO du corps de main().
 * La plomberie (lire stdin, format d'affichage) est déjà faite — elle n'a rien
 * à t'apprendre.
 *
 * Vérifier ton travail :   ./check.sh
 * ------------------------------------------------------------------------- */
#include <stdio.h>
#include <string.h>
#include <ctype.h>

/* Les mots-clés du sous-ensemble. Ce ne sont que des données : le lexer lit
 * d'abord un identifiant, PUIS consulte cette table. (C'est exactement ce que
 * fait chibicc avec son is_keyword().) */
static const char *KEYWORDS[] = { "void", "const", "int", "float", "for", "return", NULL };

/* Les ponctuateurs du sous-ensemble.
 *
 *  ⚠️  L'ordre de ce tableau n'est PAS anodin, et il est mauvais tel quel.
 *      Si ton diff affiche « + » puis « = » là où expected.txt attend « += »,
 *      tu viens de découvrir pourquoi. Réordonne.                            */
static const char *PUNCTS[] = {
    "+=", "-=", "*=", "/=", "==", "!=", "<=", ">=", "++", "--",
    "+", "-", "*", "/", "=", "<", ">", "(", ")", "[", "]", "{", "}", ";", ",",
    
    NULL
};

/* Affiche un token. Utilise ceci pour que ta sortie soit comparable à
 * expected.txt : emit("IDENT", debut_du_lexeme, longueur). */
static void emit(const char *kind, const char *lexeme, int len) {
    printf("%-8s %.*s\n", kind, len, lexeme);
}

/* Renvoie 1 si les `len` caractères à partir de `s` forment un mot-clé. */
static int is_keyword(const char *s, int len) {
       
    /* TODO 1 — parcourir KEYWORDS et comparer (attention : comparer AUSSI la
     * longueur, sinon "integer" matcherait "int"). */

    for (int i = 0; KEYWORDS[i] != NULL; i++) {
        const char *kw = KEYWORDS[i];
        if ((int)strlen(kw) == len && strncmp(s, kw, len) == 0)
            return 1;
    }
    return 0;
}

/* Renvoie la longueur du ponctuateur qui commence en `p`, ou 0 si aucun. */
static int read_punct(const char *p) {
    /* TODO 2 — parcourir PUNCTS et renvoyer la longueur du premier qui
     * correspond au début de `p`. */
    int len =0;
    for (int i =0; PUNCTS[i] != NULL; i++){
        const char *pct = PUNCTS[i];
        len = strlen(pct);
        if (strncmp(p, pct, len) == 0){
            return len;
        }
    }
    
    return 0;
}

int main(void) {
    static char buf[65536];
    size_t n = fread(buf, 1, sizeof(buf) - 1, stdin);
    buf[n] = '\0';

    char *p = buf;
    while (*p) {
         /* TODO 3 — sauter ce qui ne produit pas de token :
         *   - les espaces, tabulations et retours à la ligne  (isspace)
         *   - les commentaires  // jusqu'à la fin de ligne
         *   - les commentaires de bloc, ouverts par slash-etoile et fermes
         *     par etoile-slash (chercher la sequence de fermeture)
         * Dans chaque cas : avancer p, puis `continue;`. */
        if(isspace((unsigned char) *p)){
            p++;
            continue;
        }
        /* Commentaire de ligne : on saute jusqu'au '\n' (ou la fin du texte) */
        if (strncmp(p, "//", 2) == 0) {
            p += 2;
            while (*p != '\n' && *p != '\0'){
                p++;
                continue;               // le '\n' sera mangé par le test isspace      
            }
        }

        /* Commentaire de bloc : on cherche la fermeture */
        if (strncmp(p, "/*", 2) == 0) {
            const char *q = strstr(p + 2, "*/");
            if (q == NULL){
                fprintf(stderr, "commentaire non ferme\n");
                return 1;
            }
            p = (char *) q + 2;              // juste après le "*/"
            continue;
            }

        

       

        /* TODO 4 — reconnaître un token, dans cet ordre :
         *
         *   a) un NUMBER  : commence par un chiffre. Consommer les chiffres,
         *      puis un éventuel '.' suivi de chiffres, puis un éventuel
         *      suffixe 'f'. Émettre "NUM".
         *
         *   b) un IDENT ou un KEYWORD : commence par une lettre ou '_'.
         *      Consommer lettres, chiffres et '_'. PUIS seulement, appeler
         *      is_keyword() pour décider du kind ("KEYWORD" ou "IDENT").
         *
         *   c) un PUNCT : appeler read_punct(). Si la longueur est > 0,
         *      émettre "PUNCT" et avancer p d'autant.
         *
         * Si rien ne correspond : message d'erreur sur stderr, return 1. */

        //pour les nombres
        if (isdigit((unsigned char)*p) || (*p == '.' && isdigit((unsigned char)p[1]))) {
            const char *start = p;

            while (isdigit((unsigned char)*p))
                p++;

            if (*p == '.') {
                p++;
                while (isdigit((unsigned char)*p))
                    p++;
                if (*p == 'f' || *p == 'F')
                    p++;
            }

            

            emit("NUM", start, (int)(p - start));
            continue;
        }
        
        // Pour IDENT ou KEYWORD
        if (isalpha((unsigned char)*p) || *p == '_'){
            const char *start = p;
            p++;
            while (isalnum((unsigned char)*p) || *p == '_')
                p++;

            int len = (int)(p - start);
            if (is_keyword(start, len))
                emit("KEYWORD", start, len);
            else
                emit("IDENT", start, len);
            continue;
        }
        

        // Pour les PUNCT
        int len = read_punct(p);
        if (len > 0) {
            emit("PUNCT", p, len);
            p += len;
            continue;
}


        fprintf(stderr, "caractere inattendu: '%c'\n", *p);
        return 1;
    }


    printf("EOF\n");
    return 0;
}
