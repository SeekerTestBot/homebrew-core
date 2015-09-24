class Dmd < Formula
  desc "D programming language compiler for OS X"
  homepage "http://dlang.org"

  stable do
    url "https://github.com/D-Programming-Language/dmd/archive/v2.068.2.tar.gz"
    sha256 "787115a406d06b303be819da7e1ec978399373838f473d6b8446be400152c8fc"

    resource "druntime" do
      url "https://github.com/D-Programming-Language/druntime/archive/v2.068.2.tar.gz"
      sha256 "da9f514078015b218e81e77c54c0da967f6ed4dddc3ecbc1db98ac9aa7f79e98"
    end

    resource "phobos" do
      url "https://github.com/D-Programming-Language/phobos/archive/v2.068.2.tar.gz"
      sha256 "1135038ea4e927d5aeb0436057064ade808799d6e5180578b520c4fbc9e0914e"
    end

    resource "tools" do
      url "https://github.com/D-Programming-Language/tools/archive/v2.068.2.tar.gz"
      sha256 "9abe5b0ba60aae3341131533e99e6cdcf085040aabb596382f4ada1a018b6608"
    end
  end

  bottle do
    sha256 "f9d6bf2f5b2985a638f2668244ae9022101a452337966ced9605f877f1c07755" => :el_capitan
    sha256 "299e743830a1bf9f3ce699bf1197015037ed733451134f8aff692a5962e4c53b" => :yosemite
    sha256 "0edba178cdcb6221807b4729f21118fec804910d8ac297d7785cf3303ee2ab50" => :mavericks
    sha256 "36f6979d5208fde59177239d81bde37174bc7574bff7748c4cb859cc3d755712" => :mountain_lion
  end

  head do
    url "https://github.com/D-Programming-Language/dmd.git"

    resource "druntime" do
      url "https://github.com/D-Programming-Language/druntime.git"
    end

    resource "phobos" do
      url "https://github.com/D-Programming-Language/phobos.git"
    end

    resource "tools" do
      url "https://github.com/D-Programming-Language/tools.git"
    end
  end

  def install
    make_args = ["INSTALL_DIR=#{prefix}", "MODEL=#{Hardware::CPU.bits}", "-f", "posix.mak"]

    system "make", "SYSCONFDIR=#{etc}", "TARGET_CPU=X86", "AUTO_BOOTSTRAP=1", "RELEASE=1", *make_args

    bin.install "src/dmd"
    prefix.install "samples"
    man.install Dir["docs/man/*"]

    # A proper dmd.conf is required for later build steps:
    conf = buildpath/"dmd.conf"
    # Can't use opt_include or opt_lib here because dmd won't have been
    # linked into opt by the time this build runs:
    conf.write <<-EOS.undent
        [Environment]
        DFLAGS=-I#{include}/d2 -L-L#{lib}
        EOS
    etc.install conf
    install_new_dmd_conf

    make_args.unshift "DMD=#{bin}/dmd"

    (buildpath/"druntime").install resource("druntime")
    (buildpath/"phobos").install resource("phobos")

    system "make", "-C", "druntime", *make_args
    system "make", "-C", "phobos", "VERSION=#{buildpath}/VERSION", *make_args

    (include/"d2").install Dir["druntime/import/*"]
    cp_r ["phobos/std", "phobos/etc"], include/"d2"
    lib.install Dir["druntime/lib/*", "phobos/**/libphobos2.a"]

    resource("tools").stage do
      inreplace "posix.mak", "install: $(TOOLS) $(CURL_TOOLS)", "install: $(TOOLS) $(ROOT)/dustmite"
      system "make", "install", *make_args
    end
  end

  # Previous versions of this formula may have left in place an incorrect
  # dmd.conf.  If it differs from the newly generated one, move it out of place
  # and warn the user.
  # This must be idempotent because it may run from both install() and
  # post_install() if the user is running `brew install --build-from-source`.
  def install_new_dmd_conf
    conf = etc/"dmd.conf"

    # If the new file differs from conf, etc.install drops it here:
    new_conf = etc/"dmd.conf.default"
    # Else, we're already using the latest version:
    return unless new_conf.exist?

    backup = etc/"dmd.conf.old"
    opoo "An old dmd.conf was found and will be moved to #{backup}."
    mv conf, backup
    mv new_conf, conf
  end

  def post_install
    install_new_dmd_conf
  end

  test do
    system bin/"dmd", prefix/"samples/hello.d"
    system "./hello"
  end
end
