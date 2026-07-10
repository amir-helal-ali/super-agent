// src/nn/mod.zig - تصدير كل طبقات الشبكة العصبية
pub const tensor = @import("tensor.zig");
pub const linear = @import("linear.zig");
pub const embedding = @import("embedding.zig");
pub const attention = @import("attention.zig");
pub const transformer = @import("transformer.zig");

pub const Tensor = tensor.Tensor;
pub const TensorError = tensor.TensorError;
pub const Linear = linear.Linear;
pub const Embedding = embedding.Embedding;
pub const PositionalEncoding = embedding.PositionalEncoding;
pub const MultiHeadAttention = attention.MultiHeadAttention;
pub const TransformerBlock = transformer.TransformerBlock;
