//
//  ContentView.swift
//  Recycle Radar
//
//  Created by Victor Xiao on 12/1/21.
//
import SwiftUI
import AVFoundation
import CoreML
import Foundation
import UIKit


// extension to uiimage


class GlobalImage {
    static var shared = GlobalImage()


    var image: UIImage = UIImage(imageLiteralResourceName: "placeholder")
}

extension UIImage {

    func convertToBuffer() -> CVPixelBuffer? {

        let attributes = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary

        var pixelBuffer: CVPixelBuffer?

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault, Int(self.size.width),
            Int(self.size.height),
            kCVPixelFormatType_32ARGB,
            attributes,
            &pixelBuffer)

        guard (status == kCVReturnSuccess) else {
            return nil
        }

        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))

        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()

        let context = CGContext(
            data: pixelData,
            width: Int(self.size.width),
            height: Int(self.size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)

        context?.translateBy(x: 0, y: self.size.height)
        context?.scaleBy(x: 1.0, y: -1.0)

        UIGraphicsPushContext(context!)
        self.draw(in: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
        UIGraphicsPopContext()

        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))

        return pixelBuffer
    }
}

func testModel() -> RecycleRadarOutput? {

    do{

        let config = MLModelConfiguration()
        let model = try RecycleRadar(configuration: config)

        let prediction = try model.prediction(image: GlobalImage.shared.image.convertToBuffer()!)
        return prediction

    }
    catch{
        print("error here")
    }

    return nil
}


struct ContentView: View {
        let predictedClass = testModel()!.classLabel
    
    var body: some View {
        ZStack{
            CameraView()
            VStack{
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.myGreen)
                        .ignoresSafeArea()
                        .frame(width: 415, height: 100)
                    Text("Recycle Radar")
                        .font(.system(size: 50, weight: .heavy, design: .default))
                        .bold()
                        .foregroundColor(Color.myDarkBlue)
                        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 0)
                        .padding(.top,15)
                    
                    Spacer()
                }
                Spacer()
                Spacer()
//                Text(predictedClass)
            }
        }
    }
}


struct CameraView: View{
    
    @StateObject var camera = CameraModel()
    
    var body: some View{
        ZStack{
            CameraPreview(camera: camera).ignoresSafeArea(.all, edges: .all)
            VStack{
                Spacer()

                
                HStack{
                    if camera.isTaken {
                        Button {
                            if !camera.isSaved{camera.savePic()}
                        } label: {
                            Text(camera.isSaved ? "Saved" : "Save")
                                .foregroundColor(Color.myDarkBlue)
                                .fontWeight(.semibold)
                                .padding(.vertical,10)
                                .padding(.horizontal,20)
                                .background(Color.white)
                                .clipShape(Capsule())
                        }
                        .padding(.leading)
                        
                        Spacer()
                    }
                    else {
                        Button {
                            camera.takePic()
                            print("taken picture")
                        } label: {
                            ZStack{
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 70, height: 70)
                                
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                                    .frame(width: 75, height: 75)
                            }
                        }
                    }
                    if camera.isTaken{
                        Button {
                            camera.reTake()
                        } label: {
                            Image(systemName: "camera.on.rectangle.fill")
                                .foregroundColor(Color.black)
                                .padding()
                                .background(Color.white)
                                .clipShape(Circle())
                                .padding()
                        }
                    }
                }
                .frame(height: 75)
            }
        }
        .onAppear(perform: {
            camera.check()
        })
    }
}

//Camera Model
class CameraModel: NSObject,ObservableObject, AVCapturePhotoCaptureDelegate{
    @Published var isTaken = false
    
    @Published var session = AVCaptureSession()
    
    @Published var alert = false
    
    @Published var output = AVCapturePhotoOutput()
    
    @Published var preview : AVCaptureVideoPreviewLayer!
    
    @Published var isSaved = false
    
    @Published var picData = Data(count: 0)
    
    func check(){
        
        //first checking camera has got permission
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setUp()
            return
            //Setting Up Session
        case .notDetermined:
            //restrusting
            AVCaptureDevice.requestAccess(for: .video) { (status) in
                if status{
                    self.setUp()
                }
            }
        case .denied:
            self.alert.toggle()
            return
        default:
            return
            
        }
        
    }
    
    func setUp() {
        //setting up camera
        do{
            //setting configs
            self.session.beginConfiguration()
            
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            
            
            let input = try AVCaptureDeviceInput(device: device!)
            
            if self.session.canAddInput(input){
                self.session.addInput(input)
            }
            
            if self.session.canAddOutput(self.output){
                self.session.addOutput(self.output)
            }
            self.session.commitConfiguration()
        }
        catch{
            print(error.localizedDescription)
        }
    }
    
    func takePic(){
        DispatchQueue.global(qos: .background).async{
            
            
            self.output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
            self.session.stopRunning()
            DispatchQueue.main.async {
                withAnimation{self.isTaken.toggle()}
            }
        }
    }
    
    func reTake(){
        DispatchQueue.global(qos: .background).async{
            
            self.session.startRunning()
            DispatchQueue.main.async {
                withAnimation{self.isTaken.toggle()}
                
                self.isSaved = false
            }
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        
        if error != nil{
            return
        }
        print("pic taken...")
        
        guard  let imageData = photo.fileDataRepresentation() else {return}
        self.picData = imageData
    }
    func savePic(){
        let image = UIImage(data: self.picData)!
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        
        self.isSaved = true

        
        print("saved Sucessfully...")
    }
}

//setting view for preview
struct CameraPreview: UIViewRepresentable{
    
    @ObservedObject var camera : CameraModel
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        camera.preview = AVCaptureVideoPreviewLayer(session: camera.session)
        camera.preview.frame = view.frame
        
        camera.preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(camera.preview)
        
        camera.session.startRunning()
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        
    }
}


//
//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        ContentView()
//    }
//}
