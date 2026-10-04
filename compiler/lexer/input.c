void dense_layer(const float *w, const float *x, float *y, int n, int m) {
    for (int i = 0; i < m; i++) {
        float acc = 0.0f;
        for (int j = 0; j < n; j++)
            acc += w[i*n + j] * x[j];
        y[i] = acc;
    }
}
