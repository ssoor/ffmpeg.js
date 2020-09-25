# Compile FFmpeg and all its dependencies to JavaScript.
# You need emsdk environment installed and activated, see:
# <https://kripken.github.io/emscripten-site/docs/getting_started/downloads.html>.

PRE_JS = build/pre.js
POST_JS = build/post.js
PRE_JS_WEB = build/pre-web.js
POST_JS_WEB = build/post-web.js

COMMON_FILTERS = aresample scale crop overlay hstack vstack showinfo
COMMON_DEMUXERS = matroska ogg mov mp3 wav image2 concat
COMMON_DECODERS = vp8 h264 vorbis opus mp3 aac pcm_s16le mjpeg png

MP4_DEPS = \
	build/dist/lib/libmp3lame.so \
	build/dist/lib/libx264.so
	
MP4_MUXERS = mp4 mp3
MP4_ENCODERS = libx264 libmp3lame aac

WEBM_DEPS = \
	build/dist/lib/libvpx.so

WEBM_MUXERS = webm ogg
WEBM_ENCODERS = libvpx_vp8 libopus

FFMPEG_DEPS = $(MP4_DEPS) $(WEBM_DEPS)
FFMPEG_MUXERS = $(MP4_MUXERS) $(WEBM_MUXERS) null 
FFMPEG_ENCODERS = $(MP4_ENCODERS) $(WEBM_ENCODERS)

FFMPEG_BC = build/dist/ffmpeg.bc
FFMPEG_PC_PATH = ../dist/lib/pkgconfig

all: web js

js: ffmpeg.js
web: ffmpeg-web.js

clean: clean-js clean-dist \
	clean-opus clean-libvpx \
	clean-lame clean-x264 clean-ffmpeg
clean-js:
	rm -f ffmpeg*.js
clean-dist:
	cd build/ && rm -rf dist
clean-opus:
	cd build/opus && git clean -xdf
clean-libvpx:
	cd build/libvpx && git clean -xdf
clean-lame:
	cd build/lame && git clean -xdf
clean-x264:
	cd build/x264 && git clean -xdf
clean-ffmpeg:
	cd build/ffmpeg-mp4 && git clean -xdf

build/opus/configure:
	cd build/opus && ./autogen.sh

build/dist/lib/libopus.so: build/opus/configure
	cd build/opus && \
	emconfigure ./configure \
		CFLAGS=-O3 \
		--prefix="$$(pwd)/../dist" \
		--disable-static \
		--disable-doc \
		--disable-extra-programs \
		--disable-asm \
		--disable-rtcd \
		--disable-intrinsics \
		--disable-hardening \
		--disable-stack-protector \
		&& \
	emmake make -j && \
	emmake make install

build/dist/lib/libvpx.so:
	cd build/libvpx && \
	git reset --hard && \
	patch -p1 < ../libvpx-fix-ld.patch && \
	emconfigure ./configure \
		--prefix="$$(pwd)/../dist" \
		--target=generic-gnu \
		--disable-dependency-tracking \
		--disable-multithread \
		--disable-runtime-cpu-detect \
		--enable-shared \
		--disable-static \
		\
		--disable-examples \
		--disable-docs \
		--disable-unit-tests \
		--disable-webm-io \
		--disable-libyuv \
		--disable-vp8-decoder \
		--disable-vp9 \
		&& \
	emmake make -j && \
	emmake make install

build/dist/lib/libmp3lame.so:
	cd build/lame/lame && \
	git reset --hard && \
	patch -p2 < ../../lame-fix-ld.patch && \
	emconfigure ./configure \
		CFLAGS="-DNDEBUG -O3" \
		--prefix="$$(pwd)/../../dist" \
		--host=x86-none-linux \
		--disable-static \
		\
		--disable-gtktest \
		--disable-analyzer-hooks \
		--disable-decoder \
		--disable-frontend \
		&& \
	emmake make -j && \
	emmake make install

build/dist/lib/libx264.so:
	cd build/x264 && \
	emconfigure ./configure \
		--prefix="$$(pwd)/../dist" \
		--extra-cflags="-Wno-unknown-warning-option" \
		--host=x86-none-linux \
		--disable-cli \
		--enable-shared \
		--disable-opencl \
		--disable-thread \
		--disable-interlaced \
		--bit-depth=8 \
		--chroma-format=420 \
		--disable-asm \
		\
		--disable-avs \
		--disable-swscale \
		--disable-lavf \
		--disable-ffms \
		--disable-gpac \
		--disable-lsmash \
		&& \
	emmake make -j && \
	emmake make install

# TODO(Kagami): Emscripten documentation recommends to always use shared
# libraries but it's not possible in case of ffmpeg because it has
# multiple declarations of `ff_log2_tab` symbol. GCC builds FFmpeg fine
# though because it uses version scripts and so `ff_log2_tag` symbols
# are not exported to the shared libraries. Seems like `emcc` ignores
# them. We need to file bugreport to upstream. See also:
# - <https://kripken.github.io/emscripten-site/docs/compiling/Building-Projects.html>
# - <https://github.com/kripken/emscripten/issues/831>
# - <https://ffmpeg.org/pipermail/libav-user/2013-February/003698.html>
FFMPEG_COMMON_ARGS = \
	--cc=emcc \
	--ranlib=emranlib \
	--enable-cross-compile \
	--target-os=none \
	--arch=x86 \
	--disable-runtime-cpudetect \
	--disable-asm \
	--disable-fast-unaligned \
	--disable-pthreads \
	--disable-w32threads \
	--disable-os2threads \
	--disable-debug \
	--disable-stripping \
	--disable-safe-bitstream-reader \
	\
	--disable-all \
	--enable-ffmpeg \
	--enable-avcodec \
	--enable-avformat \
	--enable-avfilter \
	--enable-swresample \
	--enable-swscale \
	--disable-network \
	--disable-d3d11va \
	--disable-dxva2 \
	--disable-vaapi \
	--disable-vdpau \
	$(addprefix --enable-decoder=,$(COMMON_DECODERS)) \
	$(addprefix --enable-demuxer=,$(COMMON_DEMUXERS)) \
	--enable-protocol=file \
	$(addprefix --enable-filter=,$(COMMON_FILTERS)) \
	--disable-bzlib \
	--disable-iconv \
	--disable-libxcb \
	--disable-lzma \
	--disable-sdl2 \
	--disable-securetransport \
	--disable-xlib \
	--enable-zlib

build/dist/ffmpeg.bc:
	cd build/ffmpeg-mp4 && \
	EM_PKG_CONFIG_PATH=$(FFMPEG_PC_PATH) emconfigure ./configure \
		$(FFMPEG_COMMON_ARGS) \
		$(addprefix --enable-encoder=,$(FFMPEG_ENCODERS)) \
		$(addprefix --enable-muxer=,$(FFMPEG_MUXERS)) \
		--enable-gpl \
		--enable-libx264 \
		--extra-cflags="-s USE_ZLIB=1 -I../dist/include" \
		--extra-ldflags="-L../dist/lib -shared" && \
	sed -i 's/EXESUF=/EXESUF=.bc/' ffbuild/config.mak && \
	emmake make -j && \
	cp ffmpeg.bc ../dist/ffmpeg.bc

EMCC_COMMON_ARGS = \
	-O3 \
	--closure 1 \
	--memory-init-file 0 \
	-s WASM=0 \
	-s WASM_ASYNC_COMPILATION=0 \
	-s ASSERTIONS=0 \
	-s EXIT_RUNTIME=1 \
	-s NODEJS_CATCH_EXIT=0 \
	-s NODEJS_CATCH_REJECTION=0 \
	-s TOTAL_MEMORY=67108864 \
	--pre-js $(PRE_JS) \
	-o $@

ffmpeg.js: $(FFMPEG_DEPS) $(FFMPEG_BC) $(PRE_JS) $(POST_JS)
	emcc $(FFMPEG_BC) $(FFMPEG_DEPS) \
		--post-js $(POST_JS) \
		$(EMCC_COMMON_ARGS) -lnodefs.js

ffmpeg-web.js: $(FFMPEG_DEPS) $(FFMPEG_BC) $(PRE_JS_WEB) $(POST_JS_WEB)
	emcc $(FFMPEG_BC) $(FFMPEG_DEPS) \
		--post-js $(POST_JS_WEB) \
		$(EMCC_COMMON_ARGS) -lworkerfs.js