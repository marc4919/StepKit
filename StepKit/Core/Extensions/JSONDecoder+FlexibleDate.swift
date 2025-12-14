//
//  JSONDecoder+FlexibleDate.swift
//  StepKit
//
//  Estrategia de decodificación de fechas flexible para el backend.
//

import Foundation

extension JSONDecoder {

    /// Decodificador preconfigurado con estrategia de fechas flexible
    static var flexibleDateDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = Self.flexibleISO8601
        return decoder
    }

    /// Estrategia de decodificación que soporta múltiples formatos de fecha
    static var flexibleISO8601: JSONDecoder.DateDecodingStrategy {
        .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Intentar varios formatos de fecha
            let formats = [
                "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
                "yyyy-MM-dd'T'HH:mm:ssZ",
                "yyyy-MM-dd'T'HH:mm:ss",
                "yyyy-MM-dd"
            ]

            for format in formats {
                let formatter = DateFormatter()
                formatter.dateFormat = format
                formatter.locale = Locale(identifier: "en_US_POSIX")
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }

            // Si es ISO8601 estándar
            if let date = ISO8601DateFormatter().date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(dateString)"
            )
        }
    }
}
