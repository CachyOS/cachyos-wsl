# fish doesn't read /etc/profile.d, so mirror /etc/profile.d/cuda.sh from the cuda package
if test -r /etc/profile.d/cuda.sh
    set -gx CUDA_PATH /opt/cuda
    contains -- /opt/cuda/bin $PATH; or set -gxa PATH /opt/cuda/bin
    set -l ccbin (string match -rg "^export NVCC_CCBIN='(.*)'" < /etc/profile.d/cuda.sh)
    test -n "$ccbin"; and set -gx NVCC_CCBIN $ccbin
end
