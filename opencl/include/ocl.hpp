// ocl.hpp : une fine surcouche C++ de l'API C d'OpenCL (fourni par le parcours).
//
// Trois idées, toutes du C++ moderne :
//   - RAII : chaque objet OpenCL est rendu (clRelease...) par le destructeur de son
//     unique_ptr. Pas de fuite, même si une exception traverse la fonction.
//   - Exceptions : chaque appel est vérifié ; une erreur lève ocl::Erreur avec le
//     nom de l'appel et le nom du code d'erreur, au lieu d'un entier muet.
//   - Le journal de compilation : un kernel qui ne compile pas montre ses erreurs.
//
// Vise l'API OpenCL 1.2 : celle d'Apple (le GPU de ton Mac) et un sous-ensemble
// de PoCL (OpenCL 3.0, en CI sous Linux).
#pragma once

#define CL_TARGET_OPENCL_VERSION 120
#ifdef __APPLE__
#define CL_SILENCE_DEPRECATION   // Apple marque OpenCL comme déprécié
#include <OpenCL/opencl.h>
#else
#include <CL/cl.h>
#endif

#include <array>
#include <chrono>
#include <cstdlib>
#include <cstring>
#include <memory>
#include <stdexcept>
#include <string>
#include <type_traits>
#include <vector>

namespace ocl {

inline const char *nom_erreur(cl_int code) {
    switch (code) {
    case CL_SUCCESS: return "CL_SUCCESS";
    case CL_DEVICE_NOT_FOUND: return "CL_DEVICE_NOT_FOUND";
    case CL_OUT_OF_RESOURCES: return "CL_OUT_OF_RESOURCES";
    case CL_OUT_OF_HOST_MEMORY: return "CL_OUT_OF_HOST_MEMORY";
    case CL_MEM_OBJECT_ALLOCATION_FAILURE: return "CL_MEM_OBJECT_ALLOCATION_FAILURE";
    case CL_BUILD_PROGRAM_FAILURE: return "CL_BUILD_PROGRAM_FAILURE";
    case CL_INVALID_VALUE: return "CL_INVALID_VALUE";
    case CL_INVALID_DEVICE: return "CL_INVALID_DEVICE";
    case CL_INVALID_CONTEXT: return "CL_INVALID_CONTEXT";
    case CL_INVALID_COMMAND_QUEUE: return "CL_INVALID_COMMAND_QUEUE";
    case CL_INVALID_MEM_OBJECT: return "CL_INVALID_MEM_OBJECT";
    case CL_INVALID_PROGRAM_EXECUTABLE: return "CL_INVALID_PROGRAM_EXECUTABLE";
    case CL_INVALID_KERNEL_NAME: return "CL_INVALID_KERNEL_NAME";
    case CL_INVALID_KERNEL: return "CL_INVALID_KERNEL";
    case CL_INVALID_ARG_INDEX: return "CL_INVALID_ARG_INDEX";
    case CL_INVALID_ARG_VALUE: return "CL_INVALID_ARG_VALUE";
    case CL_INVALID_ARG_SIZE: return "CL_INVALID_ARG_SIZE";
    case CL_INVALID_KERNEL_ARGS: return "CL_INVALID_KERNEL_ARGS (un argument n'a pas été donné)";
    case CL_INVALID_WORK_DIMENSION: return "CL_INVALID_WORK_DIMENSION";
    case CL_INVALID_WORK_GROUP_SIZE: return "CL_INVALID_WORK_GROUP_SIZE (taille globale non divisible par la taille locale ?)";
    case CL_INVALID_WORK_ITEM_SIZE: return "CL_INVALID_WORK_ITEM_SIZE";
    case CL_INVALID_GLOBAL_WORK_SIZE: return "CL_INVALID_GLOBAL_WORK_SIZE";
    case CL_INVALID_BUFFER_SIZE: return "CL_INVALID_BUFFER_SIZE";
    default: return "code OpenCL inconnu";
    }
}

struct Erreur : std::runtime_error {
    cl_int code;
    Erreur(const std::string &appel, cl_int c)
        : std::runtime_error(appel + " : " + nom_erreur(c) + " (" + std::to_string(c) + ")"), code(c) {}
};

inline void verifier(cl_int code, const char *appel) {
    if (code != CL_SUCCESS) throw Erreur(appel, code);
}

// Un unique_ptr qui appelle clReleaseXxx : la mémoire du device est rendue toute seule.
template <class Handle, cl_int (*Release)(Handle)>
struct Liberer {
    void operator()(Handle h) const { if (h) Release(h); }
};
template <class Handle, cl_int (*Release)(Handle)>
using Objet = std::unique_ptr<std::remove_pointer_t<Handle>, Liberer<Handle, Release>>;

using Contexte  = Objet<cl_context, clReleaseContext>;
using File      = Objet<cl_command_queue, clReleaseCommandQueue>;
using Programme = Objet<cl_program, clReleaseProgram>;
using Noyau     = Objet<cl_kernel, clReleaseKernel>;
using Tampon    = Objet<cl_mem, clReleaseMemObject>;

// Le device choisi, son contexte et sa file de commandes.
struct Environnement {
    cl_device_id device = nullptr;
    Contexte contexte;
    File file;
    std::string description;   // « Apple M5 Pro (GPU, OpenCL 1.2) »
};

inline std::string info_device(cl_device_id d, cl_device_info quoi) {
    size_t n = 0;
    verifier(clGetDeviceInfo(d, quoi, 0, nullptr, &n), "clGetDeviceInfo");
    std::string s(n, '\0');
    verifier(clGetDeviceInfo(d, quoi, n, s.data(), nullptr), "clGetDeviceInfo");
    while (!s.empty() && (s.back() == '\0' || s.back() == ' ')) s.pop_back();
    return s;
}

// Choisit un device : OCL_DEVICE=gpu ou cpu force le type, sinon le premier GPU, sinon le premier device.
inline Environnement choisir_device() {
    const char *pref = std::getenv("OCL_DEVICE");
    cl_device_type voulu = CL_DEVICE_TYPE_ALL;
    if (pref && std::strcmp(pref, "gpu") == 0) voulu = CL_DEVICE_TYPE_GPU;
    if (pref && std::strcmp(pref, "cpu") == 0) voulu = CL_DEVICE_TYPE_CPU;

    cl_uint nplat = 0;
    verifier(clGetPlatformIDs(0, nullptr, &nplat), "clGetPlatformIDs (aucune plateforme OpenCL ?)");
    std::vector<cl_platform_id> plats(nplat);
    verifier(clGetPlatformIDs(nplat, plats.data(), nullptr), "clGetPlatformIDs");

    cl_device_id premier = nullptr, gpu = nullptr;
    for (auto p : plats) {
        cl_uint nd = 0;
        if (clGetDeviceIDs(p, voulu, 0, nullptr, &nd) != CL_SUCCESS || nd == 0) continue;
        std::vector<cl_device_id> devs(nd);
        verifier(clGetDeviceIDs(p, voulu, nd, devs.data(), nullptr), "clGetDeviceIDs");
        for (auto d : devs) {
            cl_device_type t;
            verifier(clGetDeviceInfo(d, CL_DEVICE_TYPE, sizeof t, &t, nullptr), "clGetDeviceInfo");
            if (!premier) premier = d;
            if (!gpu && (t & CL_DEVICE_TYPE_GPU)) gpu = d;
        }
    }
    cl_device_id d = gpu ? gpu : premier;
    if (!d) throw Erreur("choisir_device (OCL_DEVICE=" + std::string(pref ? pref : "") + ")", CL_DEVICE_NOT_FOUND);

    Environnement env;
    env.device = d;
    cl_int err;
    env.contexte.reset(clCreateContext(nullptr, 1, &d, nullptr, nullptr, &err));
    verifier(err, "clCreateContext");
    env.file.reset(clCreateCommandQueue(env.contexte.get(), d, 0, &err));
    verifier(err, "clCreateCommandQueue");
    cl_device_type t;
    verifier(clGetDeviceInfo(d, CL_DEVICE_TYPE, sizeof t, &t, nullptr), "clGetDeviceInfo");
    env.description = info_device(d, CL_DEVICE_NAME) + " (" +
                      (t & CL_DEVICE_TYPE_GPU ? "GPU" : t & CL_DEVICE_TYPE_CPU ? "CPU" : "autre") + ", " +
                      info_device(d, CL_DEVICE_VERSION) + ")";
    return env;
}

// Compile un programme OpenCL C, au moment de l'exécution, pour le device choisi.
// En cas d'échec, l'exception contient le journal de compilation du kernel.
inline Programme compiler(const Environnement &env, const std::string &source, const std::string &options = "") {
    const char *src = source.c_str();
    size_t len = source.size();
    cl_int err;
    Programme prog(clCreateProgramWithSource(env.contexte.get(), 1, &src, &len, &err));
    verifier(err, "clCreateProgramWithSource");
    err = clBuildProgram(prog.get(), 1, &env.device, options.c_str(), nullptr, nullptr);
    if (err != CL_SUCCESS) {
        size_t n = 0;
        clGetProgramBuildInfo(prog.get(), env.device, CL_PROGRAM_BUILD_LOG, 0, nullptr, &n);
        std::string log(n, '\0');
        clGetProgramBuildInfo(prog.get(), env.device, CL_PROGRAM_BUILD_LOG, n, log.data(), nullptr);
        throw std::runtime_error("le kernel ne compile pas :\n" + log);
    }
    return prog;
}

inline Noyau noyau(const Programme &prog, const char *nom) {
    cl_int err;
    Noyau k(clCreateKernel(prog.get(), nom, &err));
    verifier(err, ("clCreateKernel(\"" + std::string(nom) + "\")").c_str());
    return k;
}

// Un tampon en mémoire globale du device. Avec `donnees`, il est rempli à la création.
inline Tampon tampon(const Environnement &env, size_t octets, const void *donnees = nullptr) {
    cl_int err;
    cl_mem_flags drapeaux = donnees ? (CL_MEM_READ_WRITE | CL_MEM_COPY_HOST_PTR) : CL_MEM_READ_WRITE;
    Tampon t(clCreateBuffer(env.contexte.get(), drapeaux, octets, const_cast<void *>(donnees), &err));
    verifier(err, "clCreateBuffer");
    return t;
}

// L'argument numéro i du kernel. Pour un tampon, passe le Tampon lui-même.
template <class T>
inline void argument(const Noyau &k, cl_uint i, const T &valeur) {
    verifier(clSetKernelArg(k.get(), i, sizeof(T), &valeur), ("clSetKernelArg(" + std::to_string(i) + ")").c_str());
}
inline void argument(const Noyau &k, cl_uint i, const Tampon &t) {
    cl_mem m = t.get();
    verifier(clSetKernelArg(k.get(), i, sizeof(cl_mem), &m), ("clSetKernelArg(" + std::to_string(i) + ")").c_str());
}

// Lance le kernel sur une grille 2D de work-items : global = {x, y}. Si local est
// donné, il fixe la taille d'un work-group ; sinon, le pilote la choisit.
// Attend la fin du kernel et renvoie sa durée en millisecondes, mesurée par
// l'horloge de l'hôte, du lancement à la fin. On n'utilise pas les compteurs de
// profiling d'OpenCL : sur le GPU d'Apple, ils donnent des durées environ 50 fois
// trop courtes, donc des débits impossibles (vérifié le 2026-10-09).
inline double lancer(const Environnement &env, const Noyau &k, std::array<size_t, 2> global,
                     const std::array<size_t, 2> *local = nullptr) {
    const auto debut = std::chrono::steady_clock::now();
    verifier(clEnqueueNDRangeKernel(env.file.get(), k.get(), 2, nullptr, global.data(),
                                    local ? local->data() : nullptr, 0, nullptr, nullptr),
             "clEnqueueNDRangeKernel");
    verifier(clFinish(env.file.get()), "clFinish");
    const auto fin = std::chrono::steady_clock::now();
    return std::chrono::duration<double, std::milli>(fin - debut).count();
}

// Recopie un tampon du device vers la mémoire de l'hôte (lecture bloquante).
inline void lire(const Environnement &env, const Tampon &t, void *dest, size_t octets) {
    verifier(clEnqueueReadBuffer(env.file.get(), t.get(), CL_TRUE, 0, octets, dest, 0, nullptr, nullptr),
             "clEnqueueReadBuffer");
}

}  // namespace ocl
