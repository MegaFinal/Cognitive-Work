//
//  ProfileImage.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 19/08/26.
//

import SwiftUI
import Photos

struct ProfileImage: View {
    let image: UIImage?
    
    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill() // Mudado para fill para preencher o círculo perfeitamente
                    .frame(width: 285, height: 285)
                    .background(Color(.systemBackground))
            }
            else {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 285, height: 285)
                    .overlay {
                        Image(systemName: "person.fill.badge.plus")
                            .font(.system(size: 65))
                            .foregroundStyle(.gray)
                    }
            }
        }
        .clipShape(Circle())
        .shadow(radius: 5)
        .onTapGesture {
            requestPhotoGaleryAcess()
        }
    }
    // Função que chama o alerta nativo do iOS
    func requestPhotoGaleryAcess() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            switch status {
            case .authorized, .limited:
                print("Usuário permitiu. Aqui você pode abrir a galeria.")
            case .denied, .restricted:
                print("Usuário negou o acesso.")
            case .notDetermined:
                break
            @unknown default:
                break
            }
        }
    }
}
//#Preview {
//    ProfileImage()
//}
// MARK: UIKIT PROFILE IMAGE FOR MEMOJI
//struct ProfileImage: View {
//    let image: UIImage?
//
//    var body: some View {
//        Group {
//            if let image {
//                Image(uiImage: image)
//                    .resizable()
//                    .scaledToFit()
//                    .padding(15)
//                    .background(Color(.systemBackground))
//            }
//            else {
//                Circle()
//                    .fill(Color(.systemGray5))
//                    .overlay {
//                        Image(systemName: "person.fill.badge.plus")
//                            .font(.system(size: 65))
//                            .foregroundStyle(.gray)
//                    }
//            }
//        }
//        .frame(width: 285)
//        .clipShape(Circle())
//        .shadow(radius: 5)
//    }
//}
