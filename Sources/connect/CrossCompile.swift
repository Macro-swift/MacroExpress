//
//  CrossCompile.swift
//  Macro
//
//  Created by Helge Heß
//  Copyright © 2016-2020 ZeeZide GmbH. All rights reserved.
//

// Dupes to support:
// https://github.com/SPMDestinations/homebrew-tap/issues/2

import xsys
#if os(Windows)
  import WinSDK
#elseif os(Linux)
  import Glibc
#else
  import Darwin
#endif

// MARK: - Macro/xsys/timeval_any.swift

#if !os(Windows)
internal extension timespec {
  var milliseconds : Int {
    return (tv_sec * 1000) + (tv_nsec / 1000000)
  }
}
#endif


// MARK: - Macro/xsys/timespec.swift

#if os(Windows)
#elseif os(Linux)
  typealias timespec = Glibc.timespec

  extension timespec {
    
    static func monotonic() -> timespec {
      var ts = timespec()
      clock_gettime(CLOCK_MONOTONIC, &ts)
      return ts
    }
    
  }
#else // Darwin
  typealias timespec = Darwin.timespec
  typealias timeval  = Darwin.timeval

  internal extension timespec {
    
    init(_ mts: mach_timespec_t) {
      #if swift(>=4.1)
        self.init()
      #endif
      tv_sec  = __darwin_time_t(mts.tv_sec)
      tv_nsec = Int(mts.tv_nsec)
    }
    
    static func monotonic() -> timespec {
      var cclock = clock_serv_t()
      var mts    = mach_timespec_t()
      
      host_get_clock_service(mach_host_self(), SYSTEM_CLOCK, &cclock);
      clock_get_time(cclock, &mts);
      mach_port_deallocate(mach_task_self_, cclock);
      
      return timespec(mts)
    }
  }
#endif // Darwin


// MARK: - Macro/xsys/time.swift

#if !os(Windows)
#if os(Windows)
  import WinSDK
#elseif os(Linux)
  import Glibc

  typealias struct_tm = Glibc.tm
#else
  import Darwin
  
  typealias struct_tm = Darwin.tm
#endif

/// The Unix `tm` struct is essentially NSDateComponents PLUS some timezone
/// information (isDST, offset, tz abbrev name).
internal extension xsys.struct_tm {
  
  /// Create a Unix date components structure from a timestamp. This variant
  /// creates components in the local timezone.
  init(_ tm: time_t) {
    self = tm.componentsInLocalTime
  }
  
  /// Create a Unix date components structure from a timestamp. This variant
  /// creates components in the UTC timezone.
  init(utc tm: time_t) {
    self = tm.componentsInUTC
  }
  
  var utcTime : time_t {
    var tm = self
    return timegm(&tm)
  }
  var localTime : time_t {
    var tm = self
    return mktime(&tm)
  }
  
  /// Example `strftime` format (`man strftime`):
  ///   "%a, %d %b %Y %H:%M:%S GMT"
  ///
  func format(_ sf: String, defaultCapacity: Int = 100) -> String {
    var tm = self
    
    // Yes, yes, I know.
    let attempt1Capacity = defaultCapacity
    let attempt2Capacity = defaultCapacity > 1024 ? defaultCapacity * 2 : 1024
    var capacity = attempt1Capacity
    
    var buf = UnsafeMutablePointer<CChar>.allocate(capacity: capacity)
    #if swift(>=4.1)
      defer { buf.deallocate() }
    #else
      defer { buf.deallocate(capacity: capacity) }
    #endif
  
    let rc = xsys.strftime(buf, capacity, sf, &tm)
  
    if rc == 0 {
      #if swift(>=4.1)
        buf.deallocate()
      #else
        buf.deallocate(capacity: capacity)
      #endif
      capacity = attempt2Capacity
      buf = UnsafeMutablePointer<CChar>.allocate(capacity: capacity)
  
      let rc = xsys.strftime(buf, capacity, sf, &tm)
      assert(rc != 0)
      guard rc != 0 else { return "" }
    }
  
    return String(cString: buf);
  }
}

#endif // !os(Windows)


// MARK: - Macro/fs/Utils/StatStruct

#if !os(Windows)
#if os(Linux)
  import let Glibc.S_IFMT
  import let Glibc.S_IFREG
  import let Glibc.S_IFDIR
#else
  import let Darwin.S_IFMT
  import let Darwin.S_IFREG
  import let Darwin.S_IFDIR
#endif

internal extension xsys.stat_struct {
  func isFile()      -> Bool { return (st_mode & S_IFMT) == S_IFREG  }
  func isDirectory() -> Bool { return (st_mode & S_IFMT) == S_IFDIR  }
  var size : Int { return Int(st_size) }
}
#endif // !os(Windows)
