//
//  DirectoryMonitor.swift
//  GuideGuide
//
//  Created by Friedrich Pittelkow on 16.05.26.
//

import Foundation

final class DirectoryMonitor {
    private let url: URL
    private let onChange: () -> Void
    private let queue = DispatchQueue(label: "GuideGuide.DirectoryMonitor")
    private var source: DispatchSourceFileSystemObject?
    private var descriptor: CInt = -1

    init(url: URL, onChange: @escaping () -> Void) {
        self.url = url
        self.onChange = onChange
    }

    deinit {
        stop()
    }

    func start() {
        stop()

        descriptor = open(url.path(percentEncoded: false), O_EVTONLY)
        guard descriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .delete, .rename],
            queue: queue
        )

        source.setEventHandler { [weak self] in
            self?.onChange()
        }

        source.setCancelHandler { [weak self] in
            guard let self, self.descriptor >= 0 else { return }
            close(self.descriptor)
            self.descriptor = -1
        }

        self.source = source
        source.resume()
    }

    func stop() {
        source?.cancel()
        source = nil
    }
}

