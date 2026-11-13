/*
 * aifes_logits.c : les logits de référence du réseau réel, calculés par le vrai
 * AIfES, en C. Ils écrivent aifes_logits.txt, que tb/test_reseau.py compare au NPU.
 *
 * Provenance : ajouté le 2026-11-13 par le parcours.
 *
 * Il faut les deux en-têtes générés par AIfES-Converter (aifes_q7_fnn.h et
 * aifes_q7_weights.h) et les sources d'AIfES for Arduino, hors du dépôt. Depuis
 * tb/reseau/, par exemple :
 *
 *   A=~/3A/MNIST_Quentin_LONDOS/mnistAIfes/AIfES_for_Arduino/src
 *   Q=~/3A/MNIST_Quentin_LONDOS/mnistAIfes/q7/mnist-mlp-5layers-0frozen-pretrained-crossentropy-adam
 *   cc -O1 -w -I$A -I$Q -o aifes_logits aifes_logits.c \
 *      $(find $A -name '*.c' -not -path '*cmsis*' -not -path '*CMSIS*') -lm
 *   ./aifes_logits > aifes_logits.txt
 *
 * Chaque image passe par le même chemin que aifes_q7_fnn_inference : pixels
 * ramenés à p/255 - 0,5 (le prétraitement de l'entraînement), quantifiés en Q7,
 * puis l'inférence. On lit les int8 de la couche dense 5, avant le softmax.
 */
#include <stdio.h>
#include <stdint.h>

/* Hors Arduino, AIfES ne déclare pas aiprint et aiprint_uint, utilisés par l'en-tête généré. */
int aiprint(const char *s) { (void) s; return 0; }
int aiprint_uint(const char *format, unsigned int v) { (void) format; (void) v; return 0; }

#include "aifes_q7_fnn.h"

int main(void)
{
    static uint8_t pixels[64][784];
    static uint8_t etiquettes[64];
    FILE *fi = fopen("mnist_test_images.bin", "rb");
    FILE *fe = fopen("mnist_test_labels.bin", "rb");
    if (fi == NULL || fe == NULL) {
        fprintf(stderr, "lance d'abord extraire.py (fichiers .bin introuvables)\n");
        return 1;
    }
    size_t nb = fread(pixels, 784, 64, fi);
    if (fread(etiquettes, 1, nb, fe) != nb) {
        fprintf(stderr, "autant d'étiquettes que d'images, s'il te plaît\n");
        return 1;
    }
    fclose(fi);
    fclose(fe);

    if (aifes_q7_fnn_create_model() == 1) {
        fprintf(stderr, "échec de la création du modèle\n");
        return 1;
    }
    printf("# image étiquette logit0 ... logit9 (int8 de la couche dense 5, AIfES Q7 en C)\n");
    for (size_t i = 0; i < nb; i++) {
        float image[784];
        for (int k = 0; k < 784; k++)
            image[k] = pixels[i][k] / 255.0f - 0.5f;
        aitensor_t in_f32 = AITENSOR_2D_F32(input_layer_shape, image);
        aimath_q7_params_t in_q_params = { .shift = 7, .zero_point = 0 };
        int8_t in_data[784];
        aitensor_t in = AITENSOR_2D_Q7(input_layer_shape, &in_q_params, in_data);
        aimath_q7_quantize_tensor_from_f32(&in_f32, &in);

        aimath_q7_params_t out_q_params;
        int8_t out_data[10];
        aitensor_t out = AITENSOR_2D_Q7(output_layer_shape, &out_q_params, out_data);
        aialgo_inference_model(&model, &in, &out);

        int8_t *logits = (int8_t *) dense_layer_5.base.result.data;
        printf("%zu %u", i, etiquettes[i]);
        for (int j = 0; j < 10; j++)
            printf(" %d", logits[j]);
        printf("\n");
    }
    return 0;
}
