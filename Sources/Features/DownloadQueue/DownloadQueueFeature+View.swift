//
//  DownloadQueueFeature+View.swift
//  
//
//  Created by DeNeRr on 17.05.2024.
//

import Foundation
import ComposableArchitecture
import SwiftUI
import ViewComponents
import Styling

// MARK: - DownloadQueueFeature + View

extension DownloadQueueFeature.View: View {
  @MainActor public var body: some View {
   WithViewStore(store, observe: \.downloadQueue) { viewStore in
     ScrollView {
       ForEach(viewStore.state, id: \.`self`) { item in
         HStack(spacing: 6) {
           FillAspectImage(url: item.image)
             .aspectRatio(3 / 4, contentMode: .fit)
             .cornerRadius(12)
             .frame(height: 80)
           
           VStack(alignment: .leading, spacing: 6) {
             Text(item.title)
               .lineLimit(3)
               .font(.headline.weight(.medium))
               .multilineTextAlignment(.leading)
             Text(item.playlistName)
               .lineLimit(2)
               .font(.caption.weight(.medium))
               .foregroundStyle(.secondary)
               .multilineTextAlignment(.leading)
           }
           
           Spacer()
           switch item.status {
            case .suspended:
               CircularProgressView(progress: item.percentComplete, barStyle: .init(fill: .gray, width: 4, blurRadius: 0)) {
                 Image(systemName: "play.fill")
                   .resizable()
                   .aspectRatio(contentMode: .fit)
                   .padding(6)
                   .foregroundStyle(Theme.pastelRed)
               }
               .onTapGesture {
                 viewStore.send(.pause(item))
               }
               .frame(width: 30, height: 30)
            case .finished:
               Image(systemName: "checkmark.circle.fill")
                 .resizable()
                 .aspectRatio(contentMode: .fit)
                 .padding(6)
                 .foregroundStyle(Theme.pastelRed)
             case .cancelled:
               EmptyView()
             case .downloading:
               CircularProgressView(progress: item.percentComplete, barStyle: .init(fill: Theme.pastelRed, width: 4, blurRadius: 0)) {
                 Image(systemName: "pause.fill")
                   .resizable()
                   .aspectRatio(contentMode: .fit)
                   .padding(6)
                   .foregroundStyle(Theme.pastelRed)
               }
               .onTapGesture {
                 viewStore.send(.pause(item))
               }
               .frame(width: 30, height: 30)
           }
           
         }
       }
     }
     .frame(maxWidth: .infinity)
     .padding()
     .onAppear {
       viewStore.send(.didAppear)
     }
   }
  }
}
