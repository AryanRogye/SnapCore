#if os(iOS)
import simd

/// Describes the pan and zoom applied by a ``MetalImageView``.
public struct MetalImageViewport {
    /// The viewport's normalized pan offset.
    public var origin: SIMD2<Float>

    /// The viewport's zoom scale, where `1` displays the image at its default size.
    public var scale: Float

    /// Creates a viewport configuration for a Metal image.
    public init(
        origin: SIMD2<Float> = .zero,
        scale: Float = 1
    ) {
        self.origin = origin
        self.scale = scale
    }
}
#endif
