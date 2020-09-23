Pod::Spec.new do |s|

  s.name         = "ORSSerialPort"
  s.version      = "2.1.0"
  s.summary      = "Easy to use serial port library for Objective-C and Swift Mac apps."

  s.description  = <<-DESC
                   A simple, Cocoa-like library useful for programmers writing Objective-C or Swift apps for the Mac that communicate with external devices through a serial port. ORSSerialPort makes it easy to find the serial ports available on the system, configure serial ports, and send and receive data. It also includes an optional packet parsing API, and request/response API to greatly simplify structured communication with external devices.
                   DESC

  s.homepage     = "https://github.com/armadsen/ORSSerialPort"
  s.license      = "MIT"
  s.author             = { "Andrew Madsen" => "andrew@openreelsoftware.com" }
  s.social_media_url   = 'https://twitter.com/armadsen'

  s.platform     = :osx, "10.9"

  s.source       = { :git => "https://github.com/armadsen/ORSSerialPort.git", :tag => s.version.to_s }
  s.source_files  = "Source/**/*.{h,m}"
  s.private_header_files = "Source/ORSSerialBuffer.h"

  s.framework  = 'IOKit'
  s.requires_arc = true

  s.module_name = 'ORSSerial'

end
