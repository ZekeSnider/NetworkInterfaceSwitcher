build:
	swift build

release:
	swift build -c release -Xswiftc -static-stdlib

clean:
	rm -rf .build
