// src/nn/mod.zig
pub const tensor = @import("tensor.zig");
pub const linear = @import("linear.zig");
pub const embedding = @import("embedding.zig");
pub const attention = @import("attention.zig");
pub const transformer = @import("transformer.zig");
pub const autograd = @import("autograd.zig");
pub const optimizer = @import("optimizer.zig");

pub const Tensor = tensor.Tensor;
pub const TensorError = tensor.TensorError;
pub const Linear = linear.Linear;
pub const Embedding = embedding.Embedding;
pub const PositionalEncoding = embedding.PositionalEncoding;
pub const MultiHeadAttention = attention.MultiHeadAttention;
pub const TransformerBlock = transformer.TransformerBlock;
pub const Var = autograd.Var;
pub const Context = autograd.Context;
pub const Ops = autograd.Ops;
pub const backward = autograd.backward;
pub const Adam = optimizer.Adam;
pub const clipGradients = optimizer.clipGradients;
pub const createRng = tensor.createRng;
