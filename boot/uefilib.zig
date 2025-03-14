const std = @import("std");
const uefi = std.os.uefi;

// https://github.com/ziglang/zig/pull/23147
pub fn errorToStatus(err: uefi.Status.Error) uefi.Status {
    const Status = uefi.Status;
    const Error = Status.Error;

    return switch (err) {
        Error.Aborted => Status.aborted,
        Error.AccessDenied => Status.access_denied,
        Error.AlreadyStarted => Status.already_started,
        Error.BadBufferSize => Status.bad_buffer_size,
        Error.BufferTooSmall => Status.buffer_too_small,
        Error.CompromisedData => Status.compromised_data,
        Error.ConnectionFin => Status.connection_fin,
        Error.ConnectionRefused => Status.connection_refused,
        Error.ConnectionReset => Status.connection_reset,
        Error.CrcError => Status.crc_error,
        Error.DeviceError => Status.device_error,
        Error.EndOfFile => Status.end_of_file,
        Error.EndOfMedia => Status.end_of_media,
        Error.HostUnreachable => Status.host_unreachable,
        Error.HttpError => Status.http_error,
        Error.IcmpError => Status.icmp_error,
        Error.IncompatibleVersion => Status.incompatible_version,
        Error.InvalidLanguage => Status.invalid_language,
        Error.InvalidParameter => Status.invalid_parameter,
        Error.IpAddressConflict => Status.ip_address_conflict,
        Error.LoadError => Status.load_error,
        Error.MediaChanged => Status.media_changed,
        Error.NetworkUnreachable => Status.network_unreachable,
        Error.NoMapping => Status.no_mapping,
        Error.NoMedia => Status.no_media,
        Error.NoResponse => Status.no_response,
        Error.NotFound => Status.not_found,
        Error.NotReady => Status.not_ready,
        Error.NotStarted => Status.not_started,
        Error.OutOfResources => Status.out_of_resources,
        Error.PortUnreachable => Status.port_unreachable,
        Error.ProtocolError => Status.protocol_error,
        Error.ProtocolUnreachable => Status.protocol_unreachable,
        Error.SecurityViolation => Status.security_violation,
        Error.TftpError => Status.tftp_error,
        Error.Timeout => Status.timeout,
        Error.Unsupported => Status.unsupported,
        Error.VolumeCorrupted => Status.volume_corrupted,
        Error.VolumeFull => Status.volume_full,
        Error.WriteProtected => Status.write_protected,
    };
}
