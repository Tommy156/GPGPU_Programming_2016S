#include <cstdio>
#include <iostream>
#include <cstdlib>
#include "../utils/SyncedMemory.h"

using namespace std;

#define CHECK {\
	auto e = cudaDeviceSynchronize();\
	if (e != cudaSuccess) {\
		printf("At " __FILE__ ":%d, %s\n", __LINE__, cudaGetErrorString(e));\
		abort();\
	}\
}

__global__ void SomeTransform(char *input_gpu, int fsize) {
	int idx = blockIdx.x * blockDim.x + threadIdx.x;
	if (idx < fsize && input_gpu[idx] != '\n' && input_gpu[idx] != ',' &&
		input_gpu[idx] != '.') {
		int asciiChar = int(input_gpu[idx]);
		if((asciiChar >= 97 && asciiChar <= 122))
			input_gpu[idx] = char(asciiChar - 32);
	}
}

int main(int argc, char **argv)
{
	// init, and check
	if (argc != 2) {
		printf("Usage %s <input text file>\n", argv[0]);
		abort();
	}
	FILE *fp = fopen(argv[1], "r");
	if (not fp) {
		printf("Cannot open %s", argv[1]);
		abort();
	}
	// get file size
	fseek(fp, 0, SEEK_END);
	size_t fsize = ftell(fp);
	fseek(fp, 0, SEEK_SET);

	// read files
	MemoryBuffer<char> text(fsize+1);
	auto text_smem = text.CreateSync(fsize);
	CHECK;
	fread(text_smem.get_cpu_wo(), 1, fsize, fp);
	text_smem.get_cpu_wo()[fsize] = '\0';
	fclose(fp);

	// TODO: do your transform here
	char *input_gpu = text_smem.get_gpu_rw();
	// An example: transform the first 64 characters to '!'
	// Don't transform over the tail
	// And don't transform the line breaks
	int nThreads = 32;
	int nBlocks = fsize/nThreads + ((fsize % nThreads == 0) ? 0 : 1);
	SomeTransform<<<nBlocks, nThreads>>>(input_gpu, fsize);

	puts(text_smem.get_cpu_ro());
	return 0;
}
